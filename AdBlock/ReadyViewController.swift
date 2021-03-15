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

protocol ReadyVCDelegate: class {
    func startApp()
}

class ReadyViewController: NSViewController {
    @IBOutlet weak var infoTextView: NSTextView!
    
    weak var delegate: ReadyVCDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        infoTextView.delegate = self
        buildIntroInfoPage()
    }
    
    private func buildIntroInfoPage() {
        let bulletSymbol = "\u{2022} "
        let brHTML = "<br>".convertHTML()
        guard let ourParagraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle else { return }
        guard let dictionaryOptions = NSDictionary() as? [NSTextTab.OptionKey: Any] else { return }
        ourParagraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: 20, options: dictionaryOptions)]
        ourParagraphStyle.defaultTabInterval = 20
        ourParagraphStyle.firstLineHeadIndent = 0
        ourParagraphStyle.headIndent = 20
        guard let endParagraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle else { return }
        endParagraphStyle.paragraphSpacingBefore = 10
        
        infoTextView.textStorage?.append(NSLocalizedString("info.text.intro", comment: "").convertHTML(size: 14))
        infoTextView.textStorage?.append(brHTML)
        
        let logoUrl = Bundle.main.url(forResource: "AdBlockIcon3", withExtension: "png")
        let logoString = logoUrl?.absoluteString
        let logoHTML = "<img src='\(logoString ?? "")'>"
        let bulletOne = bulletSymbol.convertHTML(size: 24)
        bulletOne.append(String(format: NSLocalizedString("info.text.bullet.1", comment: ""), logoHTML).convertHTML(size: 14))
        bulletOne.addAttributes([.paragraphStyle: ourParagraphStyle], range: NSRange(location: 0, length: bulletOne.length))
        infoTextView.textStorage?.append(bulletOne)
        infoTextView.textStorage?.append(brHTML)
        
        let bulletTwo = bulletSymbol.convertHTML(size: 24)
        bulletTwo.append(NSLocalizedString("info.text.bullet.2", comment: "").convertHTML(size: 14))
        bulletTwo.addAttributes([.paragraphStyle: ourParagraphStyle], range: NSRange(location: 0, length: bulletTwo.length))
        infoTextView.textStorage?.append(bulletTwo)
        infoTextView.textStorage?.append(brHTML)
        
        let bulletThree = bulletSymbol.convertHTML(size: 24)
        bulletThree.append(String(format: NSLocalizedString("info.text.bullet.3", comment: ""), "<a href='mailto:help@getadblock.com'>", "</a>").convertHTML(size: 14))
        bulletThree.addAttributes([.paragraphStyle: ourParagraphStyle], range: NSRange(location: 0, length: bulletThree.length))
        infoTextView.textStorage?.append(bulletThree)
        infoTextView.textStorage?.append(brHTML)
        
        let contactString = String(format: NSLocalizedString("info.text.contact.text", comment: ""), "<a href='https://help.getadblock.com/'>", "</a>").convertHTML(size: 14)
        contactString.addAttributes([.paragraphStyle: endParagraphStyle], range: NSRange(location: 0, length: contactString.length))
        infoTextView.textStorage?.append(contactString)
    }
    
    @IBAction func startSurfingWebClick(_ sender: NSButton) {
        delegate?.startApp()
        NSWorkspace.shared.launchApplication("Safari")
    }
}

extension ReadyViewController: NSTextViewDelegate {
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL else {
            return false
        }
        
        if url.absoluteString.starts(with: "http") {
            if NSWorkspace.shared.openFile(url.absoluteString, withApplication: "Safari") {
                return true
            } else {
                NSWorkspace.shared.open(url)
                return true
            }
        }
        
        return false
    }
}
