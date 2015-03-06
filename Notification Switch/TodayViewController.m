//
//  TodayViewController.m
//  Notification Switch
//
//  Created by Vegard Solheim Theriault on 29/11/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import "TodayViewController.h"
#import "VSTDimmerServer.h"
#import "LightSwitchType.h"
#import "VSTLogger.h"
#import <NotificationCenter/NotificationCenter.h>

@interface TodayViewController () <NCWidgetProviding>
@property (weak, nonatomic) IBOutlet UISegmentedControl *switchTypeSelectedSegment;
@property (weak, nonatomic) IBOutlet UISwitch *autoLightSwitchSwitch;
@end

@implementation TodayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewWillAppear:(BOOL)animated
{
    [self logMessage:@"viewWillAppear"];
    [super viewWillAppear:animated];
//    self.preferredContentSize = CGSizeMake(0, 100);
    
    switch ([LightSwitchType sharedLightSwitchType].switchType) {
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
#pragma mark - Actions
/////////////////////////////

- (IBAction)toggleButtonTapped
{
    [self logMessage:@"toggleButtonTapped"];
    [[VSTDimmerServer sharedDimmerServer] requestToggleLight];
}

- (IBAction)toggleAutoSwitch:(UISwitch *)sender
{
    if (sender.isOn) {
        [LightSwitchType sharedLightSwitchType].switchType = AutoSwitchOn;
    } else {
        [LightSwitchType sharedLightSwitchType].switchType = AutoSwitchOff;
    }
}


/////////////////////////////
#pragma mark - Widget Providing Protocol
/////////////////////////////

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    
    switch ([LightSwitchType sharedLightSwitchType].switchType) {
        case AutoSwitchOn:
            [self.autoLightSwitchSwitch setOn:YES];
            break;
        case AutoSwitchOff:
            [self.autoLightSwitchSwitch setOn:NO];
            break;
            
        default:
            break;
    }

    completionHandler(NCUpdateResultNewData);
}

- (UIEdgeInsets)widgetMarginInsetsForProposedMarginInsets:(UIEdgeInsets)defaultMarginInsets
{
    return UIEdgeInsetsMake(0, 20, 0, 20);
}




/////////////////////////////
#pragma mark - Logging
/////////////////////////////

- (void)logMessage:(NSString *)message
{
    NSString *messageToBroadcast = [NSString stringWithFormat:@"TodayViewController - %@", message];
    NSLog(@"%@", messageToBroadcast);
    [[VSTLogger sharedLogger] addText:messageToBroadcast];
}

@end
