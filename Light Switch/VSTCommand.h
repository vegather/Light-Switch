//
//  VSTCommand.h
//  Dimmer 2
//
//  Created by Vegard Solheim Theriault on 25/08/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import <Foundation/Foundation.h>

#define SET_REQUEST     @"setRequest"
#define GET_REQUEST     @"getRequest"
#define SET_RESPONSE    @"setResponse"
#define GET_RESPONSE    @"getResponse"

#define ON_PARAMETER     @"ON"
#define OFF_PARAMETER    @"OFF"
#define TOGGLE_PARAMETER @"TOGGLE"
#define NONE_PARAMETER   @""

@interface VSTCommand : NSObject
+ (instancetype)commandWithCommand:(NSString *)command andParameter:(NSString *)parameter;

@property (strong, nonatomic) NSString *command;
@property (strong, nonatomic) NSString *commandParameter;
@property (strong, nonatomic) NSString *commandID;
//@property (nonatomic) BOOL acked;
@property (nonatomic) BOOL sent;
@end
