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

     func listMatches(pattern: String, inString: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
        let matches = regex.matches(in: inString, options: [], range: NSRange(location: 0, length: inString.count))
        var results: [String] = []
        
        if matches.count > 0 {
            let numOfRanges = matches[0].numberOfRanges
            for i in 0..<numOfRanges {
                let groupRange = matches[0].range(at: i)
                results.append((inString as NSString).substring(with: groupRange))
            }
        }
        
        return results
    }

    func listGroups(pattern: String, inString: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
        let matches = regex.matches(in: inString, options: [], range: NSRange(location: 0, length: inString.utf16.count))

        var groupMatches = [String]()
        for match in matches {
            let rangeCount = match.numberOfRanges

            for group in 0..<rangeCount {
                groupMatches.append((inString as NSString).substring(with: match.range(at: group)))
            }
        }

        return groupMatches
    }

    func containsMatch(pattern: String, inString: String) throws -> Bool {
        let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
        let range = NSMakeRange(0, inString.count)
        return regex.firstMatch(in: inString, options: [], range: range) != nil
    }

    func containsMatch(pattern: String, inString: String, options: NSRegularExpression.Options) throws -> Bool {
        let regex = try NSRegularExpression(pattern: pattern, options: options)
        let range = NSMakeRange(0, inString.count)
        return regex.firstMatch(in: inString, options: [], range: range) != nil
    }

    func replaceMatches(pattern: String, inString: String, replacementString: String) throws -> String? {
        let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
        let range = NSMakeRange(0, inString.count)

        return regex.stringByReplacingMatches(in: inString, options: [], range: range, withTemplate: replacementString)
    }


