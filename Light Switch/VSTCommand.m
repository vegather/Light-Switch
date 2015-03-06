//
//  VSTCommand.m
//  Dimmer 2
//
//  Created by Vegard Solheim Theriault on 25/08/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import "VSTCommand.h"
@import UIKit;

//@interface VSTCommand ()
//@property (strong, nonatomic, readwrite) NSString *command;
//@property (strong, nonatomic, readwrite) NSString *commandID;
//@end

@implementation VSTCommand
+ (instancetype)commandWithCommand:(NSString *)command andParameter:(NSString *)parameter
{
    return [[VSTCommand alloc] initWithCommand:command andParameter:parameter];
}

#define HIGHEST_RANDOM_NUMBER 10000

- (instancetype)initWithCommand:(NSString *)command andParameter:(NSString *)parameter
{
    self = [super init];
    if (self) {
        _command = command;
        _commandParameter = parameter;
        _sent = NO;
        
        NSString *timeString = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];
        timeString = [timeString substringFromIndex:timeString.length - 3]; //Gets last three numbers
        NSMutableString *randomPart = [[NSMutableString alloc] initWithFormat:@"%d", arc4random() % HIGHEST_RANDOM_NUMBER];
        
        int missingDigits = (int)([NSString stringWithFormat:@"%d", HIGHEST_RANDOM_NUMBER].length - 1) - (int)randomPart.length;
        NSLog(@"RandomPart = %@, missingDigits: %d", randomPart, missingDigits);
        for (int i = 0; i < missingDigits; ++i) {
            [randomPart insertString:@"0" atIndex:0];
        }
        
        _commandID = [NSString stringWithFormat:@"%@-%@", timeString, randomPart];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<VSTCommand --- CMD: %@:%@:%@ --- SENT: %d>", self.commandID, self.command, self.commandParameter, self.sent];
}

@end
