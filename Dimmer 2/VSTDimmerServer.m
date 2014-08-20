//
//  VSTDimmerServer.m
//  Dimmer 2
//
//  Created by Vegard Solheim Theriault on 18/08/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import "VSTDimmerServer.h"
#import "Light_Switch-Swift.h"

@interface VSTDimmerServer () <NSStreamDelegate>
@property (strong, nonatomic) NSInputStream *inputStream;
@property (strong, nonatomic) NSOutputStream *outputStream;
@property (nonatomic) BOOL shouldTurnON;
@property (nonatomic) BOOL latestRequestWasSet;
@property (nonatomic) int numberOfReattempts;                   // Used to check if I get 3 consecutive errors when connecting
@property (nonatomic) dispatch_queue_t socketQueue;
@end

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
    });
    return sharedVSTDimmerServer;
}




/////////////////////////////
#pragma mark - Public API
/////////////////////////////

- (void)requestTurnLightOn
{
    [self logMessage:@"requestTurnLightOn"];
    dispatch_async(self.socketQueue, ^{
        self.shouldTurnON = YES;
        self.latestRequestWasSet = YES;
        [self initializeNetworkConnection];
    });
}

- (void)requestTurnLightOff
{
    [self logMessage:@"requestTurnLightOff"];
    dispatch_async(self.socketQueue, ^{
        self.shouldTurnON = NO;
        self.latestRequestWasSet = YES;
        [self initializeNetworkConnection];
    });
}

- (void)requestCurrentLightStatus
{
    [self logMessage:@"requestCurrentLightStatus"];
    dispatch_async(self.socketQueue, ^{
        self.latestRequestWasSet = NO;
        [self initializeNetworkConnection];
    });
}




/////////////////////////////
#pragma mark - Network Setup and Teardown
/////////////////////////////

- (void)initializeNetworkConnection
{
    if ([self isConnectedToServer] == NO) {
        id ipId = [[NSUserDefaults standardUserDefaults] objectForKey:@"dimmerHostIPKey"];
        id portId = [[NSUserDefaults standardUserDefaults] objectForKey:@"dimmerHostPortKey"];
        BOOL hasIP = [ipId isKindOfClass:[NSString class]];
        BOOL hasPort = [portId isKindOfClass:[NSString class]];
        
        NSLog(@"Settings has IP: %@, port: %@", ipId, portId);
        
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        
        NSString *ip;
        int port;
        
        if (hasIP && hasPort)
        {
            [self logMessage:@"Using settings IP and port"];
            port = (int)[portId integerValue];
            ip = (NSString *)ipId;
        } else {
            [self logMessage:@"Using backup IP and port"];
            ip = @"95.34.37.32";
            port = 140;
        }
        
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
        [self sendRequest];
    }
}

- (void)teardownNetworkConnection
{
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
        [self logMessage:@"stream:handleEvent:"];
        switch (eventCode) {
            case NSStreamEventNone:
                self.numberOfReattempts = 0;
                
                [self logMessage:@"stream:handleEvent: - NSStreamEventNone"];
                break;
            case NSStreamEventOpenCompleted:
                self.numberOfReattempts = 0;
                
                [self logMessage:[NSString stringWithFormat:@"stream:handleEvent: - NSStreamEventOpenCompleted for stream: %@", aStream]];
                
                if ([self isConnectedToServer]) {
                    [self sendRequest];
                } else {
                    [self logMessage:@"stream:handleEvent: - Both streams are not yet up and running, so not sending request just yet."];
                }
                
                break;
            case NSStreamEventHasBytesAvailable:
                self.numberOfReattempts = 0;
                
                [self logMessage:@"stream:handleEvent: - NSStreamEventHasBytesAvailable"];
                if (aStream == self.inputStream) {
                    uint8_t buffer[1024];
                    int len;
                    
                    while ([self.inputStream hasBytesAvailable]) {
                        len = (int)[self.inputStream read:buffer maxLength:sizeof(buffer)];
                        if (len > 0) {
                            NSString *inputFromServer = [[NSString alloc] initWithBytes:buffer length:len encoding:NSASCIIStringEncoding];
                            [self logMessage:[NSString stringWithFormat:@"stream:handleEvent: - Received \"%@\" from server", inputFromServer]];
                            
                            for (NSString *response in [self individualResponsesFromString:inputFromServer]) {
                                [self handleIndividualResponseFromServer:response];
                            }
                        }
                    }
                }
                break;
            case NSStreamEventHasSpaceAvailable:
                self.numberOfReattempts = 0;
                [self logMessage:@"stream:handleEvent: - NSStreamEventHasSpaceAvailable"];
                break;
            case NSStreamEventErrorOccurred:
                [self logMessage:@"stream:handleEvent: - NSStreamEventErrorOccurred"];
                
                if (self.numberOfReattempts < 3)
                {
                    [self logMessage:[NSString stringWithFormat:@"stream:handleEvent: Starting retry number: %d", self.numberOfReattempts + 1]];
                    [self teardownNetworkConnection];
                    [self initializeNetworkConnection];
                    
                    ++self.numberOfReattempts;
                }
                else {
                    [self logMessage:@"Finished retrying"];
                    self.numberOfReattempts = 0;
                    [self teardownNetworkConnection];
                    
                    dispatch_async(self.socketQueue, ^{
                        [self.delegate didFailToTurnOnLightWithErrorMessage:@"Failed to connect to server after 3 retries."];
                    });
                }
                
                break;
            case NSStreamEventEndEncountered:
                self.numberOfReattempts = 0;
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

- (void)sendRequest
{
    [self logMessage:@"sendRequest"];
    if (self.latestRequestWasSet) {
        if (self.shouldTurnON) {
            [self setServerDimmerStateTo:YES];
        } else {
            [self setServerDimmerStateTo:NO];
        }
    } else {
        [self requestDimmerValueFromServer];
    }
}

- (void)requestDimmerValueFromServer
{
    [self logMessage:@"requestDimmerValueFromServer"];
    
    NSData *data = [@"getRequest" dataUsingEncoding:NSASCIIStringEncoding];
    [self.outputStream write:[data bytes] maxLength:[data length]];
}

- (void)setServerDimmerStateTo:(BOOL)dimmerState
{
    [self logMessage:[NSString stringWithFormat:@"setServerDimmerStateTo: Requesting to set dimmer state to: %d", dimmerState]];
    
    NSString *stringToSend = [NSString stringWithFormat:@"setRequest:%@", dimmerState ? @"ON" : @"OFF"];
    NSData *data = [stringToSend dataUsingEncoding:NSASCIIStringEncoding];
    [self.outputStream write:[data bytes] maxLength:[data length]];
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
        if ([line hasPrefix:@"getResponse"] || [line hasPrefix:@"setResponse"]) {
            [responses addObject:line];
        }
    }];
    
    [self logMessage:[NSString stringWithFormat:@"individualResponsesFromString - got responses: %@", responses]];
    
    return [responses copy];
}

- (void)handleIndividualResponseFromServer:(NSString *)responseFromServer
{
    NSArray *components = [responseFromServer componentsSeparatedByString:@":"];
    if (components.count == 2) {
        if ([components[0] isKindOfClass:[NSString class]] && [components[1] isKindOfClass:[NSString class]]) {
            if ([(NSString *)components[0] isEqualToString:@"setResponse"]) {
                BOOL tempDidTurnOn;
                if ([(NSString *)components[1] isEqualToString:@"ON"]) {
                    tempDidTurnOn = YES;
                } else if ([(NSString *)components[1] isEqualToString:@"OFF"]) {
                    tempDidTurnOn = NO;
                } else {
                    [self logMessage:[NSString stringWithFormat:@"handleResponseFromServer - Unknown second component: %@", components[1]]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate didFailToTurnOnLightWithErrorMessage:[NSString stringWithFormat:@"Unknown second component: %@", components[1]]];
                    });
                }
                [self logMessage:[NSString stringWithFormat:@"handleResponseFromServer - Responding to delegate that the light did turn: %d", tempDidTurnOn]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (tempDidTurnOn) {
                        [self.delegate lightDidTurnOn];
                    } else {
                        [self.delegate lightDidTurnOff];
                    }
                });
            } else if ([(NSString *)components[0] isEqualToString:@"getResponse"]) {
                BOOL tempIsOn;
                if ([(NSString *)components[1] isEqualToString:@"ON"]) {
                    tempIsOn = YES;
                } else if ([(NSString *)components[1] isEqualToString:@"OFF"]) {
                    tempIsOn = NO;
                } else {
                    [self logMessage:[NSString stringWithFormat:@"handleResponseFromServer - Unknown second component: %@", components[1]]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate didFailToTurnOnLightWithErrorMessage:[NSString stringWithFormat:@"Unknown second component: %@", components[1]]];
                    });
                }
                [self logMessage:[NSString stringWithFormat:@"handleResponseFromServer - Responding to delegate that the light is currently: %d", tempIsOn]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate didRetrieveLightStatus:tempIsOn];
                });
            } else {
                [self logMessage:[NSString stringWithFormat:@"handleResponseFromServer - Unknown first component: %@", components[0]]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate didFailToTurnOnLightWithErrorMessage:[NSString stringWithFormat:@"Unknown first component: %@", components[0]]];
                });
            }
        } else {
            [self logMessage:@"handleResponseFromServer - Response did not contain NSStrings"];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate didFailToTurnOnLightWithErrorMessage:@"Response did not contain NSStrings"];
            });
        }
    } else {
        [self logMessage:[NSString stringWithFormat:@"handleResponseFromServer - Unknown response: %@", responseFromServer]];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate didFailToTurnOnLightWithErrorMessage:[NSString stringWithFormat:@"Unknown response: %@", responseFromServer]];
        });
    }
}




/////////////////////////////
#pragma mark - Network Helpers
/////////////////////////////

- (BOOL)isConnectedToServer
{
    BOOL streamStatusClosed = (self.inputStream.streamStatus == NSStreamStatusClosed && self.outputStream.streamStatus == NSStreamStatusClosed);
    BOOL streamStatusError = (self.inputStream.streamStatus == NSStreamStatusError && self.outputStream.streamStatus == NSStreamStatusError);
    BOOL streamStatusNotOpen = (self.inputStream.streamStatus == NSStreamStatusNotOpen && self.outputStream.streamStatus == NSStreamStatusNotOpen);
    
    [self logMessage:[NSString stringWithFormat:@"isConnectedToServer - streamStatusClosed: %d, streamStatusError: %d, streamStatusNotOpen: %d",
                      streamStatusClosed, streamStatusError, streamStatusNotOpen]];
    
    return !(streamStatusClosed || streamStatusError || streamStatusNotOpen);
}




/////////////////////////////
#pragma mark - Logging
/////////////////////////////

- (void)logMessage:(NSString *)message
{
    NSString *messageToBroadcast = [NSString stringWithFormat:@"VSTDimmerServer - %@", message];
    NSLog(@"%@", messageToBroadcast);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[MWLogger sharedLogger] addText:messageToBroadcast];
    });
}

@end
