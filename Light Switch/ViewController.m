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
#import "VSTLogger.h"
#import "LightSwitchType.h"

@import CoreLocation;

@interface ViewController () <VSTDimmerBeaconDelegate, VSTDimmerServerDelegate>
@property (weak, nonatomic) IBOutlet UIButton *lightSwitchButton;
@property (weak, nonatomic) IBOutlet UISwitch *autoLightSwitchSwitch;
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
    self.lightSwitchButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    
    self.lightSwitchButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [[VSTDimmerServer sharedDimmerServer] requestCurrentLightStatus];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    SwitchType lightSwitchType = [LightSwitchType sharedLightSwitchType].switchType;
    
    switch (lightSwitchType) {
        case AutoSwitchOn:
            [self.autoLightSwitchSwitch setOn:YES];
            break;
        case AutoSwitchOff:
            [self.autoLightSwitchSwitch setOn:NO];
            break;
            
        default:
            break;
    }
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

- (IBAction)autoSwitchToggled:(UISwitch *)sender
{
    if (sender.isOn) {
        [LightSwitchType sharedLightSwitchType].switchType = AutoSwitchOn;
    } else {
        [LightSwitchType sharedLightSwitchType].switchType = AutoSwitchOff;
    }
}



/////////////////////////////
#pragma mark - Dimmer Server Delegate
/////////////////////////////

- (void)lightDidTurnOn
{
    [self logMessage:@"lightDidTurnOn"];
    self.isON = YES;
    
    [self presentLocalNotificationWithMessage:@"Your lights just turned on. Welcome home!"];
}

- (void)lightDidTurnOff
{
    [self logMessage:@"lightDidTurnOff"];
    self.isON = NO;
    
    [self presentLocalNotificationWithMessage:@"Your lights just turned off. Travel safely!"];
}

- (void)didRetrieveLightStatus:(BOOL)isOn
{
    [self logMessage:[NSString stringWithFormat:@"didRetrieveLightStatus: %d", isOn]];
    self.isON = isOn;
}

- (void)didFailToTurnOnLightWithErrorMessage:(NSString *)errorMessage
{
    [self logMessage:[NSString stringWithFormat:@"didFailToTurnOnLightWithErrorMessage: %@", errorMessage]];
    
    [self presentLocalNotificationWithMessage:errorMessage];
}




/////////////////////////////
#pragma mark - Dimmer Beacon Delegate
/////////////////////////////

- (void)gotHome
{
    [self logMessage:@"gotHome"];
    
    if ([LightSwitchType sharedLightSwitchType].switchType == AutoSwitchOn) {
        [[VSTDimmerServer sharedDimmerServer] requestTurnLightOn];
    } else {
        [self logMessage:@"gotHome, but switchType was AutoSwitchOff, so nothing happened"];
    }
}

- (void)leftHome
{
    [self logMessage:@"leftHome"];
    
    if ([LightSwitchType sharedLightSwitchType].switchType == AutoSwitchOn) {
        [[VSTDimmerServer sharedDimmerServer] requestTurnLightOff];
    } else {
        [self logMessage:@"leftHome, but switchType was AutoSwitchOff, so nothing happened"];
    }
}




/////////////////////////////
#pragma mark - Logging
/////////////////////////////

- (void)logMessage:(NSString *)message
{
    NSString *messageToBroadcast = [NSString stringWithFormat:@"ViewController - %@", message];
    NSLog(@"%@", messageToBroadcast);
    [[VSTLogger sharedLogger] addText:messageToBroadcast];
}




/////////////////////////////
#pragma mark - Helper Methods
/////////////////////////////

- (void)presentLocalNotificationWithMessage:(NSString *)message
{
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody = message;
    notification.alertAction = @"launch dimmer"; // Will show as "Slide to launch dimmer".
    notification.soundName = UILocalNotificationDefaultSoundName;
    
    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
}

@end


