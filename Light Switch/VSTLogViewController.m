//
//  VSTLogViewController.m
//  Dimmer 2
//
//  Created by Vegard Solheim Theriault on 22/09/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import "VSTLogViewController.h"
#import "VSTLogger.h"
@import MessageUI;

@interface VSTLogViewController () <UITableViewDataSource, UITableViewDelegate, MFMailComposeViewControllerDelegate>
@property (weak, nonatomic) IBOutlet UITableView *logTableView;
@property (weak, nonatomic) IBOutlet UIButton *clearButton;
@property (weak, nonatomic) IBOutlet UIButton *mailButton;
@property (weak, nonatomic) IBOutlet UIButton *refreshButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *doneButton;

@end

@implementation VSTLogViewController

/////////////////////////////
#pragma mark - View Controller Life Cycle
/////////////////////////////

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.logTableView.layer.borderColor = [UIColor colorWithWhite:0.8 alpha:1.0].CGColor;
    self.logTableView.layer.borderWidth = 1 / self.view.contentScaleFactor;
    
    [self.clearButton addTarget:self
                         action:@selector(clearButtonTapped)
               forControlEvents:UIControlEventTouchUpInside];
    
    [self.mailButton addTarget:self
                        action:@selector(mailButtonTapped)
              forControlEvents:UIControlEventTouchUpInside];
    
    [self.refreshButton addTarget:self
                           action:@selector(refreshButtonTapped)
                 forControlEvents:UIControlEventTouchUpInside];
    
    [self.doneButton setTarget:self];
    [self.doneButton setAction:@selector(doneButtonTapped)];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(loggerDidAddElement)
                                                 name:kVSTLoggerDidAddNewElementNotification
                                               object:[VSTLogger sharedLogger]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(loggerDidClear)
                                                 name:kVSTLoggerDidClearLogNotification
                                               object:[VSTLogger sharedLogger]];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kVSTLoggerDidAddNewElementNotification
                                                  object:[VSTLogger sharedLogger]];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kVSTLoggerDidClearLogNotification
                                                  object:[VSTLogger sharedLogger]];
}




/////////////////////////////
#pragma mark - Actions
/////////////////////////////

- (void)clearButtonTapped
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Are you sure?"
                                                                   message:@"Are you sure you want to clear the log? You should mail it to the developers first."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *clear = [UIAlertAction actionWithTitle:@"Clear"
                                                    style:UIAlertActionStyleDestructive
                                                  handler:^(UIAlertAction *action) {
                                                      [[VSTLogger sharedLogger] clearLog];
                                                  }];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel"
                                                     style:UIAlertActionStyleCancel
                                                   handler:nil];
    
    [alert addAction:clear];
    [alert addAction:cancel];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)mailButtonTapped
{
    if ([MFMailComposeViewController canSendMail]) {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateStyle = NSDateFormatterMediumStyle;
        
        NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        
        [[VSTLogger sharedLogger] mailPresentableTextWithCompletionHandler:^(NSString *mailText, NSError *error) {
            NSData *mailData = [mailText dataUsingEncoding:NSUTF8StringEncoding
                                      allowLossyConversion:NO];
            NSString *fileName = [NSString stringWithFormat:@"%@ - Log #%lu.txt", appName, [self getNumberOfLogsSent] + 1];
            
            MFMailComposeViewController *composer = [[MFMailComposeViewController alloc] init];
            [composer setSubject:[NSString stringWithFormat:@"%@ Log - %@", appName, [dateFormatter stringFromDate:[NSDate date]]]];
            [composer setToRecipients:@[@"vegard@wrongbag.com"]];
            [composer addAttachmentData:mailData mimeType:@"text/txt" fileName:fileName];
            composer.mailComposeDelegate = self;
            [self presentViewController:composer animated:YES completion:nil];
        }];
    }
    else {
        [self presentErrorAlertWithTitle:@"Mail not available"
                              andMessage:@"It appears you don't have mail set up on your phone. Go to Settings and add your mail address"];
    }
}

- (void)refreshButtonTapped
{
    [self.logTableView reloadData];
}

- (void)doneButtonTapped
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}



/////////////////////////////
#pragma mark - Table View Data Source
/////////////////////////////

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[VSTLogger sharedLogger] numberOfLogEntries];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LogCell" forIndexPath:indexPath];
    
    cell.textLabel.text = [[VSTLogger sharedLogger] logPresentableTextForIndexPath:indexPath];
    cell.textLabel.numberOfLines = 0;
    
    return cell;
}




/////////////////////////////
#pragma mark - Logger Notifications
/////////////////////////////

- (void)loggerDidAddElement
{
    
}

- (void)loggerDidClear
{
    [self.logTableView reloadData];
}




/////////////////////////////
#pragma mark - Mail Management
/////////////////////////////

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error
{
    [self dismissViewControllerAnimated:YES completion:nil];
    
    if (!error) {
        switch (result) {
            case MFMailComposeResultCancelled:
                break;
            case MFMailComposeResultFailed:
                [self presentErrorAlertWithTitle:@"Failed to send your mail" andMessage:@"result is MFMailComposeResultFailed"];
                break;
            case MFMailComposeResultSaved:
                [self sentOneMoreLogMail];
                [self presentErrorAlertWithTitle:@"Saved" andMessage:@"Your draft saved successfully"];
                break;
            case MFMailComposeResultSent:
                [self sentOneMoreLogMail];
                break;
                
            default: break;
        }
    } else {
        switch (error.code) {
            case MFMailComposeErrorCodeSendFailed:
                [self presentErrorAlertWithTitle:@"Failed to send your mail" andMessage:error.localizedDescription];
                break;
            case MFMailComposeErrorCodeSaveFailed:
                [self presentErrorAlertWithTitle:@"Failed to save your draft" andMessage:error.localizedDescription];
                break;
                
            default: break;
        }
    }
}

#define NUMBER_OF_LOGS_SENT_KEY @"NUMBER_OF_LOGS_SENT"

- (NSUInteger)getNumberOfLogsSent
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    if ([userDefaults integerForKey:NUMBER_OF_LOGS_SENT_KEY] == 0) {
        [userDefaults setInteger:0 forKey:NUMBER_OF_LOGS_SENT_KEY];
        [userDefaults synchronize];
        return 0;
    } else {
        return [userDefaults integerForKey:NUMBER_OF_LOGS_SENT_KEY];
    }
}

- (void)sentOneMoreLogMail
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSInteger numberOfMailSent = [userDefaults integerForKey:NUMBER_OF_LOGS_SENT_KEY];
    ++numberOfMailSent;
    
    [userDefaults setInteger:numberOfMailSent forKey:NUMBER_OF_LOGS_SENT_KEY];
    [userDefaults synchronize];
}



/////////////////////////////
#pragma mark - Helper Methods
/////////////////////////////

- (void)presentErrorAlertWithTitle:(NSString *)title andMessage:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel"
                                                     style:UIAlertActionStyleCancel
                                                   handler:nil];
    
    [alert addAction:cancel];
    
    [self presentViewController:alert animated:YES completion:nil];

}

@end
