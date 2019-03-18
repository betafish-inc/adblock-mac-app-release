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

import Cocoa
import SwiftyBeaver

class DebugVC: NSViewController {
    @IBOutlet weak var debugTextView: NSTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        debugTextView.string = getDebugInfoString()
    }
    
    private func getDebugInfoString() -> String {
        var debugString = ""
        var userPrefs = ""
        var checksumResult = ""
        var emptyRulesResult = ""
        
        if let userPrefUrl = Constants.AssetsUrls.userPreferenceUrl, let userPrefText = FileManager.default.contents(atPath: userPrefUrl.path), let userPrefString = String(data: userPrefText, encoding: .utf8) {
            userPrefs = userPrefString
        } else {
            userPrefs = "Couldn't read user preferences file."
        }
        
        if let bundledChecksumPath = Bundle.main.path(forResource: "assets_checksum", ofType: "json", inDirectory: "Assets"), let assetsChecksumPath = Constants.AssetsUrls.assetsChecksumUrl, FileManager.default.contentsEqual(atPath: bundledChecksumPath, andPath: assetsChecksumPath.path) {
            checksumResult = "VALID"
        } else {
            checksumResult = "INVALID"
        }
        
        if let bundledEmptyRulesPath = Bundle.main.path(forResource: "empty_rules", ofType: "json", inDirectory: "Assets/ContentBlocker"), let assetsEmptyRulesPath = Constants.AssetsUrls.emptyRulesUrl, FileManager.default.contentsEqual(atPath: bundledEmptyRulesPath, andPath: assetsEmptyRulesPath.path) {
            emptyRulesResult = "VALID"
        } else {
            emptyRulesResult = "INVALID"
        }
        
        debugString = "--- User Preferences ---\r\n" + userPrefs + "\r\n\r\n"
        debugString += "--- Checksum Status ---\r\n" + checksumResult + "\r\n\r\n"
        debugString += "--- Empty Rules Status ---\r\n" + emptyRulesResult + "\r\n\r\n"
        debugString += "--- Executable Location ---\r\n" + Bundle.main.bundleURL.deletingLastPathComponent().absoluteString
        
        return debugString
    }
}
