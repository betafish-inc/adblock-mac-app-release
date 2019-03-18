/*******************************************************************************
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see {http://www.gnu.org/licenses/}.
 
 */

/* This file was taken from AdBlock's iOS app, and then modified to use
 Swift 4 and MacOS APIs */

import Foundation

enum FilterOptions : UInt8 {
    case NONE = 0
    case THIRDPARTY = 1
    case MATCHCASE = 2
    case FIRSTPARTY = 4
}

var ElementTypes : [String:Int] = [
    "NONE" : 0,
    "script" : 1,
    "image" : 2,
    "background" : 4,
    "stylesheet" : 8,
    "object" : 16,
    "subdocument" : 32,
    "object_subrequest" : 64,
    "media" : 128,
    "other" : 256,
    "xmlhttprequest" : 512,
    "DEFAULTTYPES" : 1023,
    "document" : 1024,
    "elemhide" : 2048,
    "popup" : 4096,
    "generichide" : 8192,
    "genericblock" : 16384,
    "websocket" : 32768,
    "ping" : 65536,
    "font" : 131072,
    "webrtc" : 262144,
    "csp" : 524288,
]

var ChromeOnlyElementTypes = ElementTypes["NONE"]! | ElementTypes["other"]! | ElementTypes["xmlhttprequest"]!

enum FilterRuleError : Error {
    case invalidOption(sourceRule:String, unknownOption: String)
    case invalidSelector(sourceRule:String)
    case invalidDomain(domain:String)
    case invalidRegex(sourceRule:String)
    case snippetsNotAllowed(sourceRule:String)
    case invalidContentFilterText(sourceRule:String)
}
