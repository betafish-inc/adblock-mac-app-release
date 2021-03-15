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

import Foundation

enum ValidationResult: String {
    case valid, invalid
    
    var stringValue: String {
        return self.rawValue.capitalized
    }
}

protocol DebugModelType {
    var description: String { get }
}

struct DebugInfo: DebugModelType {
    var description: String {
        return """
        --- User Preferences ---
        \(userPrefs)
        
        --- Checksum Status ---
        \(checksumResult.stringValue)
        
        --- Empty Rules Status ---
        \(emptyRulesResult.stringValue)
        
        --- Executable Location ---
        \(Bundle.main.bundleURL.deletingLastPathComponent().absoluteString)
        """
    }
    
    private var userPrefs: String {
        if let userPrefUrl = URL.userPreferenceFile,
            let userPrefText = FileManager.default.contents(atPath: userPrefUrl.path),
            let userPrefs = String(data: userPrefText, encoding: .utf8) {
            return userPrefs
        } else {
            return "Couldn't read user preferences file."
        }
    }
    
    private var checksumResult: ValidationResult {
        if let bundledChecksumPath = Bundle.main.path(forResource: "assets_checksum", ofType: "json", inDirectory: "Assets"),
            let assetsChecksumPath = URL.assetsChecksumFile,
            FileManager.default.contentsEqual(atPath: bundledChecksumPath, andPath: assetsChecksumPath.path) {
            return .valid
        } else {
            return .invalid
        }
    }
    
    private var emptyRulesResult: ValidationResult {
        if let bundledEmptyRulesPath = Bundle.main.path(forResource: "empty_rules", ofType: "json", inDirectory: "Assets/ContentBlocker"),
            let assetsEmptyRulesPath = URL.emptyRulesFile,
            FileManager.default.contentsEqual(atPath: bundledEmptyRulesPath, andPath: assetsEmptyRulesPath.path) {
            return .valid
        } else {
            return .invalid
        }
    }
}
