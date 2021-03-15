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
import Cocoa

extension String {
    func convertHTML(size: Int = 20) -> NSMutableAttributedString {
        let modifiedString = "<style>body{font-family: 'LucidaGrande'; font-size: \(size)px;}</style>\(self)"

        guard let data = modifiedString.data(using: .utf8) else {
            return NSMutableAttributedString()
        }

        do {
            return try NSMutableAttributedString(data: data,
                                                 options: [.documentType: NSMutableAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
                                                 documentAttributes: nil)
        } catch {
            return NSMutableAttributedString()
        }
    }
    
    func toAttributed(highlight: String, with attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let ranges = rangesOfString(selection: highlight)
        let attributedString = NSMutableAttributedString(string: self)
        for range in ranges {
            attributedString.addAttributes(attributes, range: range)
        }
        
        return attributedString
    }
    
    func toAttributed(highlight: [String], with attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let mutableAttributedString = NSMutableAttributedString(string: self)
        
        for selected in highlight {
            let ranges = rangesOfString(selection: selected)
            for range in ranges {
                mutableAttributedString.addAttributes(attributes, range: range)
            }
        }
        
        return mutableAttributedString
    }
    
    func rangesOfString(selection: String) -> [NSRange] {
        let ranges: [NSRange]
        
        do {
            // Create the regular expression.
            let regex = try NSRegularExpression(pattern: selection, options: [])
            
            // Use the regular expression to get an array of NSTextCheckingResult.
            // Use map to extract the range from each result.
            ranges = regex.matches(in: self, options: [], range: NSRange(location: 0, length: count)).map { $0.range }
        } catch {
            // There was a problem creating the regular expression
            ranges = []
        }
        return ranges
    }
    
    func height(withConstrainedWidth width: CGFloat, font: NSFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
        return boundingBox.height
    }
    
    func listMatches(pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { return nil }
        let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: count))
        var results: [String] = []
        
        if !matches.isEmpty {
            let numOfRanges = matches[0].numberOfRanges
            for index in 0..<numOfRanges {
                let groupRange = matches[0].range(at: index)
                results.append((self as NSString).substring(with: groupRange))
            }
        }
        
        return results
    }
    
    func listGroups(pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { return nil }
        let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: utf16.count))
        
        var groupMatches = [String]()
        for match in matches {
            let rangeCount = match.numberOfRanges
            
            for group in 0..<rangeCount {
                groupMatches.append((self as NSString).substring(with: match.range(at: group)))
            }
        }
        
        return groupMatches
    }
    
    func containsMatch(pattern: String) -> Bool? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { return nil }
        return regex.firstMatch(in: self, options: [], range: NSRange(location: 0, length: count)) != nil
    }
    
    func containsMatch(pattern: String, options: NSRegularExpression.Options) -> Bool? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        return regex.firstMatch(in: self, options: [], range: NSRange(location: 0, length: count)) != nil
    }
    
    func replaceMatches(pattern: String, replacementString: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { return nil }
        return regex.stringByReplacingMatches(in: self, options: [], range: NSRange(location: 0, length: count), withTemplate: replacementString)
    }
}

extension NSMutableAttributedString {
    @discardableResult func bold(_ text: String) -> NSMutableAttributedString {
        return bold(text, 16)
    }

    @discardableResult func bold(_ text: String, _ size: CGFloat) -> NSMutableAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont(name: "LucidaGrande-Bold", size: size) as Any]
        let boldString = NSMutableAttributedString(string: text, attributes: attrs)
        append(boldString)
        return self
    }

    @discardableResult func normal(_ text: String, _ size: CGFloat) -> NSMutableAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont(name: "LucidaGrande", size: size) as Any]
        let normal = NSAttributedString(string: text, attributes: attrs)
        append(normal)

        return self
    }

    @discardableResult func normal(_ text: String) -> NSMutableAttributedString {
        return normal(text, 16)
    }
}
