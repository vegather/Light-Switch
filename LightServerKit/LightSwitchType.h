//
//  LightSwitchType.h
//  Light Switch
//
//  Created by Vegard Solheim Theriault on 01/12/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, SwitchType) {
    AutoSwitchOn,
    AutoSwitchOff,
};

@interface LightSwitchType : NSObject
+ (instancetype)sharedLightSwitchType;
@property (nonatomic) SwitchType switchType;
@end
