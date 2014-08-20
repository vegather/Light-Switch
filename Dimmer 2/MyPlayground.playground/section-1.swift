// Playground - noun: a place where people can play

import UIKit

var str: NSString = "getResponse:ONsetResponse:OFFoeuONeuthOFFgetResponse:ON"

str = str.stringByReplacingOccurrencesOfString("ON", withString: "ON\r\n")
str = str.stringByReplacingOccurrencesOfString("OFF", withString: "OFF\r\n")

var responses = [String]()

str.enumerateLinesUsingBlock { (line: String!, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
    if line.hasPrefix("setResponse") || line.hasPrefix("getResponse") {
        responses.append(line)
    }
}

println(responses)