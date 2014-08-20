//
//  MWLogger.swift
//  MOON Bag
//
//  Created by Vegard Solheim Theriault on 03/07/14.
//  Copyright (c) 2014 MOON Wearables. All rights reserved.
//

import UIKit

// Notification Center Constants
let MWLoggerDidAddNewElement = "MWLoggerDidAddNewElement"
let MWLoggerDidClearLog = "MWLoggerDidClearLog"

class MWLogger: NSObject {
    
    
    
    // -------------------------------
    // MARK: Public API
    // -------------------------------
    
    class func sharedLogger() -> MWLogger
    {
        struct Singleton
        {
            static let instance = MWLogger()
        }
        return Singleton.instance
    }
    
    func addText(textToAdd: String)
    {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        
        let currentIndex = userDefaults.integerForKey(_numberOfItemsInLogKey)
        
        let timeFormatter = NSDateFormatter()
        timeFormatter.timeStyle = NSDateFormatterStyle.MediumStyle
        
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateStyle = NSDateFormatterStyle.MediumStyle
        
        let key = "\(_loggerKeyKey)\(currentIndex)"
        let value = "\(dateFormatter.stringFromDate(NSDate())) - \(timeFormatter.stringFromDate(NSDate())) --- \(textToAdd)"
        
        userDefaults.setObject(value, forKey: key)
        userDefaults.setInteger(currentIndex + 1, forKey: _numberOfItemsInLogKey)
        userDefaults.synchronize()
        
        NSNotificationCenter.defaultCenter().postNotificationName(MWLoggerDidAddNewElement, object: self)
    }
    
    func clearLog()
    {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        
        for index in 0..<userDefaults.integerForKey(_numberOfItemsInLogKey) {
            userDefaults.removeObjectForKey("\(_loggerKeyKey)\(index)")
        }
        userDefaults.removeObjectForKey(_numberOfItemsInLogKey)
        userDefaults.synchronize()
        
        NSNotificationCenter.defaultCenter().postNotificationName(MWLoggerDidClearLog, object: self)
    }
    
    func logPresentableTextForIndexPath(indexPath: NSIndexPath) -> String
    {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        
        var text = "No log entry at index: \(indexPath.row). Highest index is \(max(0, userDefaults.integerForKey(_numberOfItemsInLogKey)) - 1)"
        if userDefaults.objectForKey("\(_loggerKeyKey)\(indexPath.row)") {
            let uncertainLogEntry = userDefaults.objectForKey("\(_loggerKeyKey)\(indexPath.row)") as? String
            if let definiteLogEntry = uncertainLogEntry {
                text = definiteLogEntry
            }
        }
        
        return text
    }
    
    var mailPresentableText: String
    {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        
        var fullText = ""
        for index in 0..<userDefaults.integerForKey(_numberOfItemsInLogKey) {
            fullText += (userDefaults.objectForKey("\(_loggerKeyKey)\(index)") as? String)!
            fullText += "\n"
        }
        
        return fullText
    }
    
    var numberOfLogEntries: Int
    {
        return NSUserDefaults.standardUserDefaults().integerForKey(_numberOfItemsInLogKey)
    }
    
    
    
    // -------------------------------
    // MARK: Private Constants
    // -------------------------------
    
    let _numberOfItemsInLogKey = "MWLogger - numerOfItemsInLog"
    let _loggerKeyKey = "MWLogger - logEntry"
}
