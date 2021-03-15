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

extension NSControl {
    @IBInspectable
    var useLucidaGrandeRegularFont: Bool {
        set(value) {
            if value {
                font = NSFont(name: "LucidaGrande", size: font?.pointSize ?? 12)
            }
        }
        get {
            return false
        }
    }
    
    @IBInspectable
    var useLucidaGrandeBoldFont: Bool {
        set(value) {
            if value {
                font = NSFont(name: "LucidaGrande-Bold", size: font?.pointSize ?? 12)
            }
        }
        get {
            return false
        }
    }
    
    @IBInspectable
    var textLineHeightMultiplier: CGFloat {
        set(value) {
            let textParagraph: NSMutableParagraphStyle = NSMutableParagraphStyle()
            textParagraph.lineHeightMultiple = value
            attributedStringValue = NSAttributedString(string: stringValue, attributes: [.paragraphStyle: textParagraph])
        }
        get {
            return 1
        }
    }
    
    @IBInspectable
    var borderColor: NSColor? {
        set(value) {
            wantsLayer = true
            layer?.borderColor = value?.cgColor
        }
        get {
            return NSColor(cgColor: layer?.borderColor ?? NSColor.black.cgColor)
        }
    }
    
    @IBInspectable
    var borderWidth: CGFloat {
        set(value) {
            wantsLayer = true
            layer?.borderWidth = value
        }
        get {
            return layer?.borderWidth ?? 0
        }
    }
    
    @IBInspectable
    var cornerRadius: CGFloat {
        set(value) {
            wantsLayer = true
            layer?.cornerRadius = value
        }
        get {
            return layer?.cornerRadius ?? 0
        }
    }
}
