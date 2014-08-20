//
//  MWLogViewController.swift
//  MOON Bag
//
//  Created by Vegard Solheim Theriault on 03/07/14.
//  Copyright (c) 2014 MOON Wearables. All rights reserved.
//

import UIKit
import MessageUI

class MWLogViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MFMailComposeViewControllerDelegate {

    @IBOutlet var logTableView : UITableView!
//    @IBOutlet var clearButton : UIButton!
//    @IBOutlet var mailButton : UIButton!
//    @IBOutlet var cancelButton : UIButton!
    
    
    
    // -------------------------------
    // MARK: View Controller Life Cycle
    // -------------------------------
    
    override func viewDidLoad()
    {
        println("Did load log VC with frame \(self.view.frame)")
        self.logTableView.layer.borderColor = UIColor(white: 0.8, alpha: 1.0).CGColor
        self.logTableView.layer.borderWidth = 0.5
        
//        self.clearButton.addTarget(self, action: "_clearButtonTapped", forControlEvents: UIControlEvents.TouchUpInside)
//        self.mailButton.addTarget(self, action: "_mailButtonTapped", forControlEvents: UIControlEvents.TouchUpInside)
//        self.cancelButton.addTarget(self, action: "_cancelButtonTapped", forControlEvents: UIControlEvents.TouchUpInside)
    }
    
    override func viewWillAppear(animated: Bool)
    {
        println("Will appear")
        
//        NSNotificationCenter.defaultCenter().addObserver(
//            self,
//            selector: "loggerDidAddElement",
//            name: MWLoggerDidAddNewElement,
//            object: MWLogger.sharedLogger())
        
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "loggerDidClearLog",
            name: MWLoggerDidClearLog,
            object: MWLogger.sharedLogger())
        
        self.logTableView.reloadData()
        
//        self.logTableView.scrollToRowAtIndexPath(
//            NSIndexPath(forRow: max(0, MWLogger.sharedLogger().numberOfLogEntries - 1), inSection: 0),
//            atScrollPosition: UITableViewScrollPosition.Bottom,
//            animated: false)
    }
    
    override func viewDidDisappear(animated: Bool)
    {
        println("Did disappear")
        
        NSNotificationCenter.defaultCenter().removeObserver(
            self,
            name: MWLoggerDidAddNewElement,
            object: MWLogger.sharedLogger())
        
        NSNotificationCenter.defaultCenter().removeObserver(
            self,
            name: MWLoggerDidClearLog,
            object: MWLogger.sharedLogger())
    }
    
    
    
    // -------------------------------
    // MARK: Table View Data Source
    // -------------------------------
    
    func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int
    {
        return MWLogger.sharedLogger().numberOfLogEntries
    }
    
    func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell!
    {
        let cell = tableView.dequeueReusableCellWithIdentifier("LogCell", forIndexPath: indexPath) as? UITableViewCell
        
        if let definiteCell = cell {
            definiteCell.textLabel.text = MWLogger.sharedLogger().logPresentableTextForIndexPath(indexPath)
            definiteCell.textLabel.numberOfLines = 0
        }
        
        return cell
    }
    
    
    
    // -------------------------------
    // MARK: Logger Notifications
    // -------------------------------
    
//    func loggerDidAddElement()
//    {
////        self.logTableView.beginUpdates()
//        self.logTableView.insertRowsAtIndexPaths(
//            [NSIndexPath( forRow: max(0, MWLogger.sharedLogger().numberOfLogEntries - 1), inSection: 0)],
//            withRowAnimation: UITableViewRowAnimation.Bottom)
////        self.logTableView.endUpdates()
//        
////        self.logTableView.scrollToRowAtIndexPath(
////            NSIndexPath(forRow: max(0, MWLogger.sharedLogger().numberOfLogEntries - 1), inSection: 0),
////            atScrollPosition: UITableViewScrollPosition.Bottom,
////            animated: true)
//    }
    
    func loggerDidClearLog()
    {
        self.logTableView.reloadData()
    }
    
    
    
    // -------------------------------
    // MARK: Actions
    // -------------------------------
    
    @IBAction func _clearButtonTapped()
    {
        let alert = UIAlertController(
            title: "Are You Sure",
            message: "Are you sure you want to clear the log? You should mail it to the developers first.",
            preferredStyle: UIAlertControllerStyle.Alert)
        
        let clear = UIAlertAction(
            title: "Clear",
            style: UIAlertActionStyle.Destructive,
            handler: {(action: UIAlertAction!) -> Void in
                MWLogger.sharedLogger().clearLog()
            })
        
        let cancel = UIAlertAction(
            title: "Cancel",
            style: UIAlertActionStyle.Cancel,
            handler: nil)
        
        alert.addAction(clear)
        alert.addAction(cancel)
        
        self.presentViewController(alert, animated: true, completion: nil)
    }

    @IBAction func _mailButtonTapped()
    {
        self._sendMail()
    }

    @IBAction func _refreshButtonTapped()
    {
        self.logTableView.reloadData()
        self.logTableView.scrollToRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0),
            atScrollPosition: UITableViewScrollPosition.Top,
            animated: true)
    }
    
    @IBAction func _doneButtonTapped(sender: UIBarButtonItem)
    {
        if let navController = self.navigationController {
            navController.presentingViewController.dismissViewControllerAnimated(true, completion: nil)
        } else {
            self.presentingViewController.dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    
    
//    @IBAction func _cancelButtonTapped()
//    {
//        self.logTableView.reloadData()
//        self.presentingViewController.dismissViewControllerAnimated(true, completion: nil)
//    }

    
    
    
    // -------------------------------
    // MARK: Mail Management
    // -------------------------------

    private func _sendMail()
    {
        if MFMailComposeViewController.canSendMail() {
            let dateFormatter = NSDateFormatter()
            dateFormatter.dateStyle = NSDateFormatterStyle.MediumStyle
            
            let appName = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleDisplayName") as String
            
            let mailData = MWLogger.sharedLogger().mailPresentableText.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
            println("Data to mail: \(mailData?.length) bytes")
            let composer = MFMailComposeViewController()
            composer.setSubject("\(appName) Log - \(dateFormatter.stringFromDate(NSDate()))")
            composer.setToRecipients(["vegard@wrongbag.com"])
            composer.addAttachmentData(mailData, mimeType: "text/txt", fileName: "\(appName) - Log\(self._getNumberOfLogsSent() + 1).txt")
            composer.mailComposeDelegate = self
            self.presentViewController(
                composer,
                animated: true,
                completion: nil)
        } else {
            self._presentErrorAlertWithTitle("Mail Not Available", andMessage: "It appears you don't have mail set up on your phone. Go to Settings and add your mail address")
        }
    }
    
    func mailComposeController(controller:MFMailComposeViewController, didFinishWithResult result:MFMailComposeResult, error:NSError)
    {
        if error == nil {
            if result.value == MFMailComposeResultFailed.value {
                self._presentErrorAlertWithTitle("Failed", andMessage: "The mail composer failed")
            }
            else if result.value == MFMailComposeResultSent.value {
                self._sentOneMoreLog()
            }
        }
        else {
            if MFMailComposeErrorCode(CUnsignedInt(error.code)).value == MFMailComposeErrorCodeSaveFailed.value {
                self._presentErrorAlertWithTitle("Failed", andMessage: "The mail composer failed to save your draft")
            }
            else if MFMailComposeErrorCode(CUnsignedInt(error.code)).value == MFMailComposeErrorCodeSendFailed.value {
                self._presentErrorAlertWithTitle("Failed", andMessage: "The mail composer failed to send your mail")
            }
        }
        println("Dismissing mail VC")
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    
    let NUMBER_OF_LOGS_SENT_KEY = "NUMBER_OF_LOGS_SENT"
    
    private func _getNumberOfLogsSent() -> Int
    {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        
        if  userDefaults.integerForKey(NUMBER_OF_LOGS_SENT_KEY) == 0 {
            userDefaults.setInteger(0, forKey: NUMBER_OF_LOGS_SENT_KEY)
            userDefaults.synchronize()
            return 0
        } else {
            return userDefaults.integerForKey(NUMBER_OF_LOGS_SENT_KEY)
        }
    }
    
    private func _sentOneMoreLog()
    {
        var mailSent = NSUserDefaults.standardUserDefaults().integerForKey(NUMBER_OF_LOGS_SENT_KEY)
        mailSent++
        NSUserDefaults.standardUserDefaults().setInteger(mailSent, forKey: NUMBER_OF_LOGS_SENT_KEY)
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    
    
    // -------------------------------
    // MARK: Private API
    // -------------------------------
    
    private func _presentErrorAlertWithTitle(title: String, andMessage message: String)
    {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        let dismiss = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil)
        self.presentViewController(alert, animated: true, completion: nil)
    }
}
