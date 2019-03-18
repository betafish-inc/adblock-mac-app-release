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
        let modifiedString = "<style>body{font-family: 'LucidaGrande'; font-size: \(size)px;}</style>\(self)";

        guard let data = modifiedString.data(using: .utf8) else {
            return  NSMutableAttributedString()
        }

        do {
            return try NSMutableAttributedString(data: data, options: [.documentType: NSMutableAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil)
        } catch {
            return NSMutableAttributedString()
        }
    }
    
    func toAttributed(highlight: String, with attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let ranges = rangesOfString(s: highlight)
        let attributedString = NSMutableAttributedString(string:self)
        for range in ranges {
            attributedString.addAttributes(attributes, range: range)
        }
        
        return attributedString
    }
    
    func toAttributed(highlight: [String], with attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let mutableAttributedString = NSMutableAttributedString(string:self)
        
        for s in highlight {
            let ranges = rangesOfString(s: s)
            for range in ranges {
                mutableAttributedString.addAttributes(attributes, range: range)
            }
        }
        
        return mutableAttributedString
    }
    
    func rangesOfString(s: String) -> [NSRange] {
        let ranges: [NSRange]
        
        do {
            // Create the regular expression.
            let regex = try NSRegularExpression(pattern: s, options: [])
            
            // Use the regular expression to get an array of NSTextCheckingResult.
            // Use map to extract the range from each result.
            ranges = regex.matches(in: self, options: [], range: NSMakeRange(0, self.count)).map {$0.range}
        }
        catch {
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
}

extension NSMutableAttributedString {
    @discardableResult func bold(_ text: String) -> NSMutableAttributedString {
        return self.bold(text, 16)
    }

    @discardableResult func bold(_ text: String, _ size:CGFloat) -> NSMutableAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont(name: "LucidaGrande-Bold", size: size) as Any]
        let boldString = NSMutableAttributedString(string:text, attributes: attrs)
        append(boldString)
        return self
    }

    @discardableResult func normal(_ text: String, _ size:CGFloat) -> NSMutableAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont(name: "LucidaGrande", size: size) as Any]
        let normal = NSAttributedString(string: text, attributes: attrs)
        append(normal)

        return self
    }

    @discardableResult func normal(_ text: String) -> NSMutableAttributedString {
        return self.normal(text, 16)
    }
}
