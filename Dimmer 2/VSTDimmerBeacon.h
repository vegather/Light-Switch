//
//  VSTDimmerBeacon.h
//  Dimmer 2
//
//  Created by Vegard Solheim Theriault on 18/08/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol VSTDimmerBeaconDelegate <NSObject>
- (void)gotHome;
- (void)leftHome;
@end

@interface VSTDimmerBeacon : NSObject
- (instancetype)initWithDelegate:(id <VSTDimmerBeaconDelegate>)delegate;
@end
