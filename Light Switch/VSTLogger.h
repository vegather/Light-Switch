//
//  VSTLogger.h
//  Dimmer 2
//
//  Created by Vegard Solheim Theriault on 22/09/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const kVSTLoggerDidAddNewElementNotification;
extern NSString *const kVSTLoggerDidClearLogNotification;

@interface VSTLogger : NSObject

+ (VSTLogger *)sharedLogger;
- (void)addText:(NSString *)textToAdd;
- (void)clearLog;
- (NSString *)logPresentableTextForIndexPath:(NSIndexPath *)indexPath;
- (void)mailPresentableTextWithCompletionHandler:(void (^)(NSString *mailText, NSError *error))completionHandler;
- (NSInteger)numberOfLogEntries;

@end
