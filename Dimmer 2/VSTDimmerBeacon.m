//
//  VSTDimmerBeacon.m
//  Dimmer 2
//
//  Created by Vegard Solheim Theriault on 18/08/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import "VSTDimmerBeacon.h"
#import "Light_Switch-Swift.h"
@import CoreLocation;


@interface VSTDimmerBeacon () <CLLocationManagerDelegate>
@property (strong, nonatomic) id<VSTDimmerBeaconDelegate> delegate;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLBeaconRegion *beaconRegion;
@property (nonatomic) BOOL isHome;
@end

@implementation VSTDimmerBeacon


/////////////////////////////
#pragma mark - Initializer
/////////////////////////////

- (instancetype)initWithDelegate:(id <VSTDimmerBeaconDelegate>)delegate
{
    self = [super init];
    if (self) {
        [self logMessage:@"initWithDelegate"];
        
        self.delegate = delegate;
        self.isHome = NO;
        
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:@"B9407F30-F5F8-466E-AFF9-25556B57FE6D"];
        self.beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid
                                                                    major:1
                                                                    minor:99
                                                               identifier:@"Vegard Light"];
        
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        [self.locationManager requestAlwaysAuthorization];
        [self.locationManager requestStateForRegion:self.beaconRegion];
        [self.locationManager startMonitoringForRegion:self.beaconRegion];
    }
    return self;
}




/////////////////////////////
#pragma mark - Setters
/////////////////////////////

- (void)setIsHome:(BOOL)isHome
{
    [self logMessage:[NSString stringWithFormat:@"Setting isHome to: %d", isHome]];
    if (isHome && !_isHome) { // If isHome just changed to YES
        [self.delegate gotHome];
    } else if (!isHome && _isHome) { // If isHome just changed to NO
        [self.delegate leftHome];
    }
    _isHome = isHome;
}




/////////////////////////////
#pragma mark - Location Manager Delegate
/////////////////////////////

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region
{
    switch (state) {
        case CLRegionStateInside:
            [self logMessage:@"didDetermineState - Inside"];
            self.isHome = YES;
            break;
        case CLRegionStateOutside:
            [self logMessage:@"didDetermineState - Outside"];
            self.isHome = NO;
            break;
        case CLRegionStateUnknown:
            [self logMessage:@"didDetermineState - Unknown"];
            break;
            
        default:
            break;
    }
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
    [self logMessage:@"didEnterRegion"];
    self.isHome = YES;
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
    [self logMessage:@"didExitRegion"];
    self.isHome = NO;
}



/////////////////////////////
#pragma mark - Helper Methods
/////////////////////////////

- (void)logMessage:(NSString *)message
{
    NSString *messageToBroadcast = [NSString stringWithFormat:@"VSTDimmerBeacon - %@", message];
    NSLog(@"%@", messageToBroadcast);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[MWLogger sharedLogger] addText:messageToBroadcast];
    });
}

@end
