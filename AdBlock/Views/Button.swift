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

@IBDesignable
class Button: NSButton
{
    @IBInspectable var textColor: NSColor?
    
    override func awakeFromNib()
    {
        if let textColor = textColor, let font = font
        {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            
            let attributes =
                [
                    .foregroundColor: textColor,
                    .font: font,
                    .paragraphStyle: style
                    ] as [NSAttributedStringKey : Any]
            
            if title.isEmpty {
                title = " "
            }
            let attributedTitle = NSMutableAttributedString(string: title, attributes: attributes)
            self.attributedTitle = attributedTitle
        }
    }
    
    func getAttributes() -> [NSAttributedStringKey : Any]?
    {
        let buttonAttributes: [NSAttributedStringKey : Any]?
        if self.attributedTitle.string.isEmpty {
            buttonAttributes = nil
        } else {
            buttonAttributes = self.attributedTitle.attributes(at: 0, effectiveRange: nil)
        }
        
        return buttonAttributes
    }
}
