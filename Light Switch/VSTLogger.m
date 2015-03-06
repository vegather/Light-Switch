//
//  VSTLogger.m
//  Dimmer 2
//
//  Created by Vegard Solheim Theriault on 22/09/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import "VSTLogger.h"
@import UIKit;

NSString *const kVSTLoggerDidAddNewElementNotification    = @"kVSTLoggerDidAddNewElementNotification";
NSString *const kVSTLoggerDidClearLogNotification         = @"kVSTLoggerDidClearLogNotification";

#define NUMBER_OF_ITEMS_IN_LOG_KEY  @"MWLogger_numberOfItemsInLog"
#define LOG_ENTRY_KEY               @"MWLogger_logEntry"

@interface VSTLogger ()
@property (nonatomic, strong) dispatch_queue_t loggerQueue;
@end

@implementation VSTLogger

+ (VSTLogger *)sharedLogger {
    static VSTLogger *sharedLogger = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedLogger = [[self alloc] init];
        sharedLogger.loggerQueue = dispatch_queue_create("com.vegather.loggerQueue", NULL);
    });
    return sharedLogger;
}

- (void)addText:(NSString *)textToAdd
{
    dispatch_async(self.loggerQueue, ^{
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSInteger currentIndex = [userDefaults integerForKey:NUMBER_OF_ITEMS_IN_LOG_KEY];
        
        NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
        timeFormatter.timeStyle = NSDateFormatterMediumStyle;
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateStyle = NSDateFormatterMediumStyle;
        
        NSString *key   = [NSString stringWithFormat:@"%@%lu", LOG_ENTRY_KEY, (long)currentIndex];
        
        NSString *date = [dateFormatter stringFromDate:[NSDate date]];
        NSString *time = [timeFormatter stringFromDate:[NSDate date]];
        NSString *value = [NSString stringWithFormat:@"%@ - %@ --- %@", date, time, textToAdd];
        
        [userDefaults setObject:value forKey:key];
        [userDefaults setInteger:currentIndex + 1 forKey:NUMBER_OF_ITEMS_IN_LOG_KEY];
        [userDefaults synchronize];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kVSTLoggerDidAddNewElementNotification object:self];
    });
}

- (void)clearLog
{
    dispatch_async(self.loggerQueue, ^{
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        
        for (int i = 0; i < [userDefaults integerForKey:NUMBER_OF_ITEMS_IN_LOG_KEY]; ++i) {
            [userDefaults removeObjectForKey:[NSString stringWithFormat:@"%@%d", LOG_ENTRY_KEY, i]];
        }
        [userDefaults setInteger:0 forKey:NUMBER_OF_ITEMS_IN_LOG_KEY];
        [userDefaults synchronize];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kVSTLoggerDidClearLogNotification object:self];
    });
}

- (NSString *)logPresentableTextForIndexPath:(NSIndexPath *)indexPath
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSString *text = [userDefaults objectForKey:[NSString stringWithFormat:@"%@%lu", LOG_ENTRY_KEY, (long)indexPath.row]];
    
    if (!text) {
        text = [NSString stringWithFormat:@"No log entry at index: %lu. Hightest index us %ld", (long)indexPath.row, [userDefaults integerForKey:NUMBER_OF_ITEMS_IN_LOG_KEY] - 1];
    }

    return text;
}

- (void)mailPresentableTextWithCompletionHandler:(void (^)(NSString *mailText, NSError *error))completionHandler
{
    dispatch_async(self.loggerQueue, ^{
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        
        NSMutableString *fullText = [[NSMutableString alloc] initWithString:@""];
        for (int i = 0; i < [userDefaults integerForKey:NUMBER_OF_ITEMS_IN_LOG_KEY]; ++i) {
            NSString *entry = [userDefaults objectForKey:[NSString stringWithFormat:@"%@%d", LOG_ENTRY_KEY, i]];
            if (!entry) {
                entry = @"Index out of bounds";
            }
            [fullText appendFormat:@"%@\n", entry];
        }
        
        if ([fullText isEqualToString:@""]) {
            NSString *description = [NSString stringWithFormat:@"There is currently no log"];
            NSError *noLogError = [NSError errorWithDomain:@"com.vegather.error" code:404 userInfo:@{NSLocalizedDescriptionKey : description}];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, noLogError);
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler([fullText copy], nil);
            });
        }
    });
}

- (NSInteger)numberOfLogEntries
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:NUMBER_OF_ITEMS_IN_LOG_KEY];;
}

@end
