//
//  ViewController.m
//  Dimmer 2
//
//  Created by Vegard Solheim Theriault on 09/08/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import "ViewController.h"
#import "VSTDimmerServer.h"
#import "VSTDimmerBeacon.h"
#import "Light_Switch-Swift.h"
@import CoreLocation;

@interface ViewController () <VSTDimmerBeaconDelegate, VSTDimmerServerDelegate>
@property (weak, nonatomic) IBOutlet UIButton *lightSwitchButton;
@property (nonatomic) BOOL isON;
@property (strong, nonatomic) VSTDimmerBeacon *dimmerBeacon;
@end

@implementation ViewController


/////////////////////////////
#pragma mark - View Controller Life Cycle
/////////////////////////////

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self logMessage:@"viewDidLoad"];
    
    [[VSTDimmerServer sharedDimmerServer] setDelegate:self];
    self.dimmerBeacon = [[VSTDimmerBeacon alloc] initWithDelegate:self];
    
    [self.lightSwitchButton setImageEdgeInsets:UIEdgeInsetsMake(-100, -100, -100, -100)];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [[VSTDimmerServer sharedDimmerServer] requestCurrentLightStatus];
}



/////////////////////////////
#pragma mark - Setters
/////////////////////////////

- (void)setIsON:(BOOL)isON
{
    _isON = isON;
    
     [self logMessage:[NSString stringWithFormat:@"Setting isOn to: %d", _isON]];
    
    if (_isON) {
        [self.lightSwitchButton setImage:[UIImage imageNamed:@"LightOn"] forState:UIControlStateNormal];
    } else {
        [self.lightSwitchButton setImage:[UIImage imageNamed:@"LightOff"] forState:UIControlStateNormal];
    }
}




/////////////////////////////
#pragma mark - Actions
/////////////////////////////


- (IBAction)lightSwitchTapped
{
    [self logMessage:[NSString stringWithFormat:@"lightSwitchTapped - isON: %d", self.isON]];
    if (self.isON) {
        [[VSTDimmerServer sharedDimmerServer] requestTurnLightOff];
    } else {
        [[VSTDimmerServer sharedDimmerServer] requestTurnLightOn];
    }
}




/////////////////////////////
#pragma mark - Dimmer Server Delegate
/////////////////////////////

- (void)lightDidTurnOn
{
    [self logMessage:@"lightDidTurnOn"];
    self.isON = YES;
}

- (void)lightDidTurnOff
{
    [self logMessage:@"lightDidTurnOff"];
    self.isON = NO;
}

- (void)didRetrieveLightStatus:(BOOL)isOn
{
    [self logMessage:[NSString stringWithFormat:@"didRetrieveLightStatus: %d", isOn]];
    self.isON = isOn;
}

- (void)didFailToTurnOnLightWithErrorMessage:(NSString *)errorMessage
{
    [self logMessage:[NSString stringWithFormat:@"didFailToTurnOnLightWithErrorMessage: %@", errorMessage]];
    
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody = errorMessage;
    notification.alertAction = @"launch dimmer"; // Will show as "Slide to launch dimmer".
    notification.soundName = UILocalNotificationDefaultSoundName;
    
    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
}




/////////////////////////////
#pragma mark - Dimmer Beacon Delegate
/////////////////////////////

- (void)gotHome
{
    [self logMessage:@"gotHome"];
    [[VSTDimmerServer sharedDimmerServer] requestTurnLightOn];
}

- (void)leftHome
{
    [self logMessage:@"leftHome"];
    [[VSTDimmerServer sharedDimmerServer] requestTurnLightOff];
}




/////////////////////////////
#pragma mark - Logging
/////////////////////////////

- (void)logMessage:(NSString *)message
{
    NSString *messageToBroadcast = [NSString stringWithFormat:@"ViewController - %@", message];
    NSLog(@"%@", messageToBroadcast);
    [[MWLogger sharedLogger] addText:messageToBroadcast];
}

@end


