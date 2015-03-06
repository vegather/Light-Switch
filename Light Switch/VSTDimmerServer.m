//
//  VSTDimmerServer.m
//  Dimmer 2
//
//  Created by Vegard Solheim Theriault on 18/08/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import "VSTDimmerServer.h"
#import "VSTCommand.h"
#import "VSTLogger.h"
#include <unistd.h> // For sleeping while sending requests

@interface VSTDimmerServer () <NSStreamDelegate>
@property (strong, nonatomic) NSInputStream *inputStream;
@property (strong, nonatomic) NSOutputStream *outputStream;

@property (nonatomic) BOOL hasInitializeNetwork;

@property (nonatomic) BOOL inputStreamIsConnected;
@property (nonatomic) BOOL outputStreamIsConnected;

@property (nonatomic) int numberOfReattemptsForInputStream;     // Used to check if I get 3 consecutive errors when connecting
@property (nonatomic) int numberOfReattemptsForOutputStream;    // Used to check if I get 3 consecutive errors when connecting

@property (nonatomic) dispatch_queue_t socketQueue;

@property (strong, nonatomic) NSMutableArray *commandArray; // of VSTCommands
@end


#define MAX_NUMBER_OF_RETRIES 3


@implementation VSTDimmerServer


/////////////////////////////
#pragma mark - Singleton
/////////////////////////////

+ (VSTDimmerServer *)sharedDimmerServer {
    static VSTDimmerServer *sharedVSTDimmerServer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedVSTDimmerServer = [[self alloc] init];
        sharedVSTDimmerServer.socketQueue = dispatch_queue_create("Socket Queue", NULL);
        sharedVSTDimmerServer.hasInitializeNetwork = NO;
        
        sharedVSTDimmerServer.inputStreamIsConnected = NO;
        sharedVSTDimmerServer.outputStreamIsConnected = NO;
        
        sharedVSTDimmerServer.numberOfReattemptsForInputStream  = 0;
        sharedVSTDimmerServer.numberOfReattemptsForOutputStream = 0;
    });
    return sharedVSTDimmerServer;
}




/////////////////////////////
#pragma mark - Lazy Initialization
/////////////////////////////

- (NSMutableArray *)commandArray
{
    if (!_commandArray) {
        _commandArray = [[NSMutableArray alloc]init];
    }
    return _commandArray;
}




/////////////////////////////
#pragma mark - Public API
/////////////////////////////

- (void)requestTurnLightOn
{
    [self logMessage:@"requestTurnLightOn"];
    dispatch_async(self.socketQueue, ^{
        
        [self.commandArray addObject:[VSTCommand commandWithCommand:SET_REQUEST
                                                       andParameter:ON_PARAMETER]];
        
        if ([self isConnectedToServer]) {
            [self sendRequests];
        } else {
            [self initializeNetworkConnection];
        }
    });
}

- (void)requestTurnLightOff
{
    [self logMessage:@"requestTurnLightOff"];
    dispatch_async(self.socketQueue, ^{

        [self.commandArray addObject:[VSTCommand commandWithCommand:SET_REQUEST
                                                       andParameter:OFF_PARAMETER]];
        
        if ([self isConnectedToServer]) {
            [self sendRequests];
        } else {
            [self initializeNetworkConnection];
        }
    });
}

- (void)requestToggleLight
{
    [self logMessage:@"requestToggleLight"];
    dispatch_async(self.socketQueue, ^{
        [self.commandArray addObject:[VSTCommand commandWithCommand:SET_REQUEST
                                                       andParameter:TOGGLE_PARAMETER]];
        
        if ([self isConnectedToServer]) {
            [self sendRequests];
        } else {
            [self initializeNetworkConnection];
        }
    });
}

- (void)requestCurrentLightStatus
{
    [self logMessage:@"requestCurrentLightStatus"];
    dispatch_async(self.socketQueue, ^{
        [self.commandArray addObject:[VSTCommand commandWithCommand:GET_REQUEST
                                                       andParameter:NONE_PARAMETER]];
        
        if ([self isConnectedToServer]) {
            [self sendRequests];
        } else {
            [self initializeNetworkConnection];
        }
    });
}




/////////////////////////////
#pragma mark - Network Setup and Teardown
/////////////////////////////

- (void)initializeNetworkConnection
{
    if ([self isConnectedToServer] == NO && self.hasInitializeNetwork == NO) {
        self.hasInitializeNetwork = YES;
        
        id ipId = [[NSUserDefaults standardUserDefaults] objectForKey:@"dimmerHostIPKey"];
        id portId = [[NSUserDefaults standardUserDefaults] objectForKey:@"dimmerHostPortKey"];
        BOOL hasIP = [ipId isKindOfClass:[NSString class]];
        BOOL hasPort = [portId isKindOfClass:[NSString class]];
        
        NSLog(@"Settings has IP: %@, port: %@", ipId, portId);
        
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        
        NSString *ip;
        int port;

        if (hasIP) {
            [self logMessage:@"Using settings IP"];
            ip = (NSString *)ipId;
        } else {
            [self logMessage:@"Using default IP"];
            ip = @"46.9.15.252";
        }
        
        if (hasPort) {
            [self logMessage:@"Using settings port"];
            port = (int)[portId integerValue];
        } else {
            [self logMessage:@"Using default port"];
            port = 140;
        }
        
//        if (hasIP && hasPort)
//        {
//            [self logMessage:@"Using settings IP and port"];
//            port = (int)[portId integerValue];
//            ip = (NSString *)ipId;
//        } else {
//            [self logMessage:@"Using default IP and port"];
//            ip = @"95.34.37.32";
//            port = 140;
//        }
        
        [self logMessage:[NSString stringWithFormat:@"initializeNetworkConnection - Connecting to %@:%d", ip, port]];
        
        CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)ip, port, &readStream, &writeStream);
        
        self.inputStream = (__bridge_transfer NSInputStream *)readStream;
        self.outputStream = (__bridge_transfer NSOutputStream *)writeStream;
        
        self.inputStream.delegate = self;
        self.outputStream.delegate = self;
        
        [self.inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [self.outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        
        [self.inputStream open];
        [self.outputStream open];
        
        if (self.inputStream == nil) [self logMessage:@"Read stream is nil"];
        if (self.outputStream == nil) [self logMessage:@"Write stream is nil" ];
    }
    else {
        [self logMessage:@"initializeNetworkConnection - Was already connected to the server."];
//        [self sendRequests];
    }
}

- (void)teardownNetworkConnection
{
    self.hasInitializeNetwork = NO;
    self.inputStreamIsConnected = NO;
    self.outputStreamIsConnected = NO;
    
    [self logMessage:@"teardownNetworkConnection"];
    
    [self.outputStream close];
    [self.inputStream close];
    
    [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    self.inputStream = nil;
    self.outputStream = nil;
}




/////////////////////////////
#pragma mark - Network Events
/////////////////////////////

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    dispatch_async(self.socketQueue, ^{
        switch (eventCode) {
            case NSStreamEventNone:
                [self logMessage:@"stream:handleEvent: - NSStreamEventNone"];
                break;
            case NSStreamEventOpenCompleted:
                if (aStream == self.inputStream) {
                    [self logMessage:@"stream:handleEvent - Input stream did open"];
                    
                    self.numberOfReattemptsForInputStream = 0;
                    self.inputStreamIsConnected = YES;
                    if (self.outputStreamIsConnected) {
                        [self sendRequests];
                    }
                }
                else if (aStream == self.outputStream) {
                    [self logMessage:@"stream:handleEvent - Output stream did open"];
                    
                    self.numberOfReattemptsForOutputStream = 0;
                    self.outputStreamIsConnected = YES;
                    if (self.inputStreamIsConnected) {
                        [self sendRequests];
                    }
                }
                break;
            case NSStreamEventHasBytesAvailable:
                [self logMessage:@"stream:handleEvent: - NSStreamEventHasBytesAvailable"];
                if (aStream == self.inputStream) {
                    uint8_t buffer[256];
                    int len;
                    
                    while ([self.inputStream hasBytesAvailable]) {
                        len = (int)[self.inputStream read:buffer maxLength:sizeof(buffer)];
                        if (len > 0) {
                            NSString *inputFromServer = [[NSString alloc] initWithBytes:buffer length:len encoding:NSASCIIStringEncoding];
                            [self logMessage:[NSString stringWithFormat:@"stream:handleEvent: - Received \"%@\" from server", inputFromServer]];
                            
                            for (VSTCommand *response in [self individualResponsesFromString:inputFromServer]) {
                                [self handleIndividualResponseFromServer:response];
                            }
                        }
                    }
                }
                break;
            case NSStreamEventHasSpaceAvailable:
                [self sendRequests];
                
                [self logMessage:@"stream:handleEvent: - NSStreamEventHasSpaceAvailable"];
                break;
            case NSStreamEventErrorOccurred:
                [self logMessage:@"stream:handleEvent: - NSStreamEventErrorOccurred"];
                
                self.hasInitializeNetwork = NO;
                
                if (aStream == self.inputStream) {
                    if (self.numberOfReattemptsForInputStream < MAX_NUMBER_OF_RETRIES) {
                        [self logMessage:[NSString stringWithFormat:@"stream:handleEvent: Starting retry for input number: %d", self.numberOfReattemptsForInputStream + 1]];
                        [self teardownNetworkConnection];
                        [self initializeNetworkConnection];
                        self.numberOfReattemptsForInputStream++;
                    }
                    else {
                        [self logMessage:@"Done retrying to connect to inputStream"];
                        self.numberOfReattemptsForInputStream = 0;
                        [self teardownNetworkConnection];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate didFailToTurnOnLightWithErrorMessage:[NSString stringWithFormat:@"Failed to connect to input stream after %d retries", MAX_NUMBER_OF_RETRIES]];
                        });
                    }
                }
                else if (aStream == self.outputStream) {
                    if (self.numberOfReattemptsForOutputStream < MAX_NUMBER_OF_RETRIES) {
                        [self logMessage:[NSString stringWithFormat:@"stream:handleEvent: Starting retry for output number: %d", self.numberOfReattemptsForOutputStream + 1]];
                        [self teardownNetworkConnection];
                        [self initializeNetworkConnection];
                        self.numberOfReattemptsForOutputStream++;
                    }
                    else {
                        [self logMessage:@"Done retrying to connect to outputStream"];
                        self.numberOfReattemptsForOutputStream = 0;
                        [self teardownNetworkConnection];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate didFailToTurnOnLightWithErrorMessage:[NSString stringWithFormat:@"Failed to connect to output stream after %d retries", MAX_NUMBER_OF_RETRIES]];
                        });
                    }
                }
                break;
            case NSStreamEventEndEncountered:
                [self logMessage:@"stream:handleEvent: - NSStreamEventEndEncountered"];
                [self teardownNetworkConnection];
                break;
                
            default:
                break;
        }
    });
}




/////////////////////////////
#pragma mark - Server Requests
/////////////////////////////

- (void)sendRequests
{
    [self logMessage:[NSString stringWithFormat:@"sendRequests: %@", self.commandArray]];

    int retries = 0;
    for (int i = 0; i < self.commandArray.count; i++) {
        if (self.outputStream.hasSpaceAvailable) {
            retries = 0;
            VSTCommand *command = self.commandArray[i];
            if (command.sent == NO) {
                NSString *parameterSpacer = (command.commandParameter.length) ? @":" : @"";
                NSString *fullRequest = [NSString stringWithFormat:@"%@:%@%@%@", command.commandID, command.command, parameterSpacer, command.commandParameter];
                NSLog(@"FULL REQUEST: %@", fullRequest);
                NSData *data = [fullRequest dataUsingEncoding:NSASCIIStringEncoding];
                [self.outputStream write:[data bytes] maxLength:[data length]];
                command.sent = YES;
                
                [self logMessage:[NSString stringWithFormat:@"sendRequests - Just sent command: %@", command.command]];
            }
        } else if (retries < MAX_NUMBER_OF_RETRIES) {
            NSString *errorMessage = [NSString stringWithFormat:@"POTENTIAL ERROR: Sleeping. Retries: %d, outputStreamHasSpaceAvailable: %@, commandsToSend: %lu, i: %d",
                                      retries, self.outputStream.hasSpaceAvailable ? @"YES" : @"NO", [self.commandArray count], i];
            
            [self logMessage:errorMessage];
            usleep(3);
            --i;
            ++retries;
        } else {
            NSString *errorMessage = [NSString stringWithFormat:@"POTENTIAL ERROR: Output stream still has no space after 3 retries. Retries: %d, outputStreamHasSpaceAvailable: %@, commandsToSend: %lu, i: %d",
                                      retries, self.outputStream.hasSpaceAvailable ? @"YES" : @"NO", [self.commandArray count], i];
            [self logMessage:errorMessage];
            break;
        }
    }
    
//    if (self.outputStream.hasSpaceAvailable) {
//        for (VSTCommand *command in self.commandArray) {
//            
//            if (command.sent == NO) {
//                NSString *parameterSpacer = (command.commandParameter.length) ? @":" : @"";
//                NSString *fullRequest = [NSString stringWithFormat:@"%@:%@%@%@", command.commandID, command.command, parameterSpacer, command.commandParameter];
//                NSLog(@"FULL REQUEST: %@", fullRequest);
//                NSData *data = [fullRequest dataUsingEncoding:NSASCIIStringEncoding];
//                [self.outputStream write:[data bytes] maxLength:[data length]];
//                command.sent = YES;
//                
//                [self logMessage:[NSString stringWithFormat:@"sendRequests - Just sent command: %@", command.command]];
//            }
//        }
//    } else {
//        [self logMessage:@"sendRequests - Output stream does not have bytes available"];
//    }
}




/////////////////////////////
#pragma mark - Server Responses
/////////////////////////////

- (NSArray *)individualResponsesFromString:(NSString *)serverResponse
{
    [self logMessage:[NSString stringWithFormat:@"individualResponsesFromString - got input: %@", serverResponse]];
    
    serverResponse = [serverResponse stringByReplacingOccurrencesOfString:@"ON"  withString:@"ON\r\n"];
    serverResponse = [serverResponse stringByReplacingOccurrencesOfString:@"OFF" withString:@"OFF\r\n"];
    
    NSMutableArray *responses = [[NSMutableArray alloc] initWithCapacity:1];
    
    [serverResponse enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        NSArray *components = [line componentsSeparatedByString:@":"];
        if (components.count == 3) {
            if ([((NSString *)components[1]) hasPrefix:SET_RESPONSE] || [((NSString *)components[1]) hasPrefix:GET_RESPONSE]) {
                VSTCommand *command = [VSTCommand commandWithCommand:components[1] andParameter:components[2]];
                command.commandID = components[0];
                
                [responses addObject:command];
            }
        }
    }];
    
    [self logMessage:[NSString stringWithFormat:@"individualResponsesFromString - got responses: %@", responses]];
    
    return [responses copy];
}

- (void)handleIndividualResponseFromServer:(VSTCommand *)responseFromServer
{
    if (responseFromServer.commandParameter.length) {
        if ([responseFromServer.command isEqualToString:SET_RESPONSE]) {
            if ([responseFromServer.commandParameter isEqualToString:ON_PARAMETER]) {
                [self logMessage:@"handleResponseFromServer - Responding to delegate that the light did turn ON"];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate lightDidTurnOn];
                });
            } else if ([responseFromServer.commandParameter isEqualToString:OFF_PARAMETER]) {
                [self logMessage:@"handleResponseFromServer - Responding to delegate that the light did turn OFF"];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate lightDidTurnOff];
                });
            } else {
                [self logMessage:[NSString stringWithFormat:@"handleResponseFromServer - Unknown command parameter: %@", responseFromServer.commandParameter]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate didFailToTurnOnLightWithErrorMessage:[NSString stringWithFormat:@"Unknown command parameter: %@", responseFromServer.commandParameter]];
                });
            }
        } else if ([responseFromServer.command isEqualToString:GET_RESPONSE]) {
            if ([responseFromServer.commandParameter isEqualToString:ON_PARAMETER]) {
                [self logMessage:[NSString stringWithFormat:@"handleResponseFromServer - Responding to delegate that the light is currently: %@", ON_PARAMETER]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate didRetrieveLightStatus:YES];
                });
            } else if ([responseFromServer.commandParameter isEqualToString:OFF_PARAMETER]) {
                [self logMessage:[NSString stringWithFormat:@"handleResponseFromServer - Responding to delegate that the light is currently: %@", OFF_PARAMETER]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate didRetrieveLightStatus:NO];
                });
            } else {
                [self logMessage:[NSString stringWithFormat:@"handleResponseFromServer - Unknown command parameter: %@", responseFromServer.commandParameter]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate didFailToTurnOnLightWithErrorMessage:[NSString stringWithFormat:@"Unknown command parameter: %@", responseFromServer.commandParameter]];
                });
            }
        } else {
            [self logMessage:[NSString stringWithFormat:@"handleResponseFromServer - Unknown command: %@", responseFromServer.command]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate didFailToTurnOnLightWithErrorMessage:[NSString stringWithFormat:@"Unknown command: %@", responseFromServer.command]];
            });
        }
        
        [self finishedWithCommand:responseFromServer];
        
    } else {
        [self logMessage:[NSString stringWithFormat:@"handleResponseFromServer - Unknown response: %@", responseFromServer]];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate didFailToTurnOnLightWithErrorMessage:[NSString stringWithFormat:@"Unknown response: %@", responseFromServer]];
        });
    }
}




/////////////////////////////
#pragma mark - Helper Methods
/////////////////////////////

- (void)finishedWithCommand:(VSTCommand *)finishedCommand
{
    for (VSTCommand *tempCommand in self.commandArray) {
        if ([tempCommand.commandID isEqualToString:finishedCommand.commandID] && tempCommand.sent) {
            [self.commandArray removeObject:tempCommand];
            break;
        }
    }
}

- (BOOL)isConnectedToServer
{
    return self.inputStreamIsConnected && self.outputStreamIsConnected;
}




/////////////////////////////
#pragma mark - Logging
/////////////////////////////

- (void)logMessage:(NSString *)message
{
    NSString *messageToBroadcast = [NSString stringWithFormat:@"VSTDimmerServer - %@", message];
    NSLog(@"%@", messageToBroadcast);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[VSTLogger sharedLogger] addText:messageToBroadcast];
    });
}

@end
