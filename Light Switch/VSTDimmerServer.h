//
//  VSTDimmerServer.h
//  Dimmer 2
//
//  Created by Vegard Solheim Theriault on 18/08/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol VSTDimmerServerDelegate <NSObject>
- (void)lightDidTurnOn;
- (void)lightDidTurnOff;
- (void)didRetrieveLightStatus:(BOOL)isOn;
- (void)didFailToTurnOnLightWithErrorMessage:(NSString *)errorMessage;
@end

@interface VSTDimmerServer : NSObject
@property (strong, nonatomic) id<VSTDimmerServerDelegate> delegate;
+ (VSTDimmerServer *)sharedDimmerServer;
- (void)requestTurnLightOn;
- (void)requestTurnLightOff;
- (void)requestToggleLight;
- (void)requestCurrentLightStatus;
@end
