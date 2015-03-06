//
//  LightSwitchType.m
//  Light Switch
//
//  Created by Vegard Solheim Theriault on 01/12/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import "LightSwitchType.h"

#define SHARED_GROUP_ID         @"group.com.vegather.lightSwitch"

#define SHARED_AUTO_SWITCH_KEY  @"LightSwitch_Autoswitch_Key"
#define SHARED_AUTO_SWITCH_ON   @"LightSwitch_Autoswitch_On"
#define SHARED_AUTO_SWITCH_OFF  @"LightSwitch_Autoswitch_Off"

@implementation LightSwitchType


/////////////////////////////
#pragma mark - Singleton
/////////////////////////////

+ (instancetype)sharedLightSwitchType {
    static LightSwitchType *sharedLightSwitchType = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedLightSwitchType = [[self alloc] init];
    });
    return sharedLightSwitchType;
}



/////////////////////////////
#pragma mark - Accessor and Mutator
/////////////////////////////

- (SwitchType)switchType
{
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:SHARED_GROUP_ID];
    
    SwitchType returnValue;
    if ([(NSString *)[sharedDefaults objectForKey:SHARED_AUTO_SWITCH_KEY] isEqualToString:SHARED_AUTO_SWITCH_ON]) {
        NSLog(@"LightSwitchType - get autoswitch ON");
        returnValue = AutoSwitchOn;
    } else if ([(NSString *)[sharedDefaults objectForKey:SHARED_AUTO_SWITCH_KEY] isEqualToString:SHARED_AUTO_SWITCH_OFF]) {
        NSLog(@"LightSwitchType - get autoswitch OFF");
        returnValue = AutoSwitchOff;
    }
    
    return returnValue;
}

- (void)setSwitchType:(SwitchType)switchType
{
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:SHARED_GROUP_ID];
    
    switch (switchType) {
        case AutoSwitchOn:
            NSLog(@"LightSwitchType - set autoswitch ON");
            [sharedDefaults setObject:SHARED_AUTO_SWITCH_ON
                               forKey:SHARED_AUTO_SWITCH_KEY];
            break;
        case AutoSwitchOff:
            NSLog(@"LightSwitchType - set autoswitch OFF");
            [sharedDefaults setObject:SHARED_AUTO_SWITCH_OFF
                               forKey:SHARED_AUTO_SWITCH_KEY];
            break;
            
        default:
            break;
    }
    
    [sharedDefaults synchronize];
}

@end
