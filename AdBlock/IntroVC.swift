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
import SafariServices
import ServiceManagement
import SwiftyBeaver
import AppKit

protocol IntroVCDelegate {
    func startApp()
}

class IntroVC: NSViewController {
    
    @IBOutlet weak var introViewOne: NSView!
    @IBOutlet weak var introViewTwo: NSView!
    @IBOutlet weak var AdBlockReadyView: NSView!
    
    @IBOutlet weak var introOneTextField: NSTextField!
    @IBOutlet weak var introOneButton: Button!
    
    @IBOutlet weak var introTwoTextFieldOne: NSTextField!
    @IBOutlet weak var introTwoTextFieldTwo: NSTextField!
    @IBOutlet weak var introTwoTextFieldThree: NSTextField!
    @IBOutlet weak var introTwoButton: Button!
    @IBOutlet weak var introTwoSkip: NSButton!
    
    @IBOutlet weak var infoHeaderTextField: NSTextField!
    @IBOutlet var infoTextView: NSTextView!
    @IBOutlet weak var infoTextButton: Button!

    var delegate: IntroVCDelegate? = nil

    var skipLaunchAppOnUserLoginStep: Bool = false

    /// True if the application is in dark mode, and false otherwise
    var inDarkMode: Bool {
        let mode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
        return mode == "Dark"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        checkExtensionIsEnabled()
        
        introOneTextField.isEditable = false
        introOneTextField.attributedStringValue = String(NSLocalizedString("intro.screen.1.text", comment: "")).convertHTML()
        introOneButton.attributedTitle = NSAttributedString(string: NSLocalizedString("intro.screen.1.button", comment: ""), attributes: introOneButton.getAttributes())
        
        introTwoTextFieldOne.stringValue = NSLocalizedString("intro.screen.2.text.1", comment: "")
        introTwoTextFieldTwo.stringValue = NSLocalizedString("intro.screen.2.text.2", comment: "")
        introTwoTextFieldThree.stringValue = NSLocalizedString("intro.screen.2.text.3", comment: "")
        introTwoButton.attributedTitle = NSAttributedString(string: NSLocalizedString("intro.screen.2.button", comment: ""), attributes: introTwoButton.getAttributes())
        introTwoSkip.title = NSLocalizedString("intro.screen.2.skip", comment: "")
        
        infoTextView.delegate = self
        buildIntroInfoPage()
        infoHeaderTextField.stringValue = NSLocalizedString("info.text.header", comment: "")
        infoTextButton.attributedTitle = NSAttributedString(string: NSLocalizedString("info.text.button", comment: ""), attributes: infoTextButton.getAttributes())

        if #available(OSX 10.14, *) {
            introOneTextField.appearance =  NSAppearance(named: .aqua)
            introOneButton.appearance = NSAppearance(named: .aqua)
            introTwoTextFieldOne.appearance = NSAppearance(named: .aqua)
            introTwoTextFieldTwo.appearance = NSAppearance(named: .aqua)
            introTwoTextFieldThree.appearance = NSAppearance(named: .aqua)
            introTwoButton.appearance =  NSAppearance(named: .aqua)
            introTwoSkip.appearance =  NSAppearance(named: .aqua)
            infoHeaderTextField.appearance = NSAppearance(named: .aqua)
            infoTextView.appearance = NSAppearance(named: .aqua)
            infoTextButton.appearance = NSAppearance(named: .aqua)
        }
    }
    
    private func buildIntroInfoPage() {
        let bulletSymbol = "\u{2022} "
        let brHTML = "<br>".convertHTML()
        let ourParagraphStyle: NSMutableParagraphStyle
        ourParagraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        ourParagraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: 20, options: NSDictionary() as! [NSTextTab.OptionKey : Any])]
        ourParagraphStyle.defaultTabInterval = 20
        ourParagraphStyle.firstLineHeadIndent = 0
        ourParagraphStyle.headIndent = 20
        let endParagraphStyle: NSMutableParagraphStyle
        endParagraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        endParagraphStyle.paragraphSpacingBefore = 10
        
        infoTextView.textStorage?.append(NSLocalizedString("info.text.intro", comment: "").convertHTML(size: 14))
        infoTextView.textStorage?.append(brHTML)
        
        let logoUrl = Bundle.main.url(forResource: "AdBlockIcon3", withExtension: "png")
        let logoString = logoUrl?.absoluteString
        let logoHTML = "<img src='" + (logoString ?? "") + "'>"
        let bulletOne = bulletSymbol.convertHTML(size: 24)
        bulletOne.append(String(format: NSLocalizedString("info.text.bullet.1", comment: ""), logoHTML).convertHTML(size: 14))
        bulletOne.addAttributes([.paragraphStyle: ourParagraphStyle], range: NSMakeRange(0, bulletOne.length))
        infoTextView.textStorage?.append(bulletOne)
        infoTextView.textStorage?.append(brHTML)
        
        let bulletTwo = bulletSymbol.convertHTML(size: 24)
        bulletTwo.append(NSLocalizedString("info.text.bullet.2", comment: "").convertHTML(size: 14))
        bulletTwo.addAttributes([.paragraphStyle: ourParagraphStyle], range: NSMakeRange(0, bulletTwo.length))
        infoTextView.textStorage?.append(bulletTwo)
        infoTextView.textStorage?.append(brHTML)
        
        let bulletThree = bulletSymbol.convertHTML(size: 24)
        bulletThree.append(String(format: NSLocalizedString("info.text.bullet.3", comment: ""), "<a href='mailto:help@getadblock.com'>", "</a>").convertHTML(size: 14))
        bulletThree.addAttributes([.paragraphStyle: ourParagraphStyle], range: NSMakeRange(0, bulletThree.length))
        infoTextView.textStorage?.append(bulletThree)
        infoTextView.textStorage?.append(brHTML)
        
        let contactString = String(format: NSLocalizedString("info.text.contact.text", comment: ""), "<a href='https://help.getadblock.com/'>", "</a>").convertHTML(size: 14)
        contactString.addAttributes([.paragraphStyle: endParagraphStyle], range: NSMakeRange(0, contactString.length))
        infoTextView.textStorage?.append(contactString)
    }
    
    private func checkExtensionIsEnabled() {
        var safariContentBlockerEnabled = false
        var safariMenuEnabled = false
        let group = DispatchGroup()
        
        group.enter()
        DispatchQueue.main.async(group: group) {
            SFContentBlockerManager.getStateOfContentBlocker(withIdentifier: Constants.SAFARI_CONTENT_BLOCKER_EXTENSION_IDENTIFIER) { (state, error) in
                guard let state = state else {
                    SwiftyBeaver.error(error ?? "")
                    safariContentBlockerEnabled = false
                    group.leave()
                    return
                }
                
                safariContentBlockerEnabled = state.isEnabled
                group.leave()
            }
        }
        
        group.enter()
        DispatchQueue.main.async(group: group) {
            SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: Constants.SAFARI_MENU_EXTENSION_IDENTIFIER) { (state, error) in
                guard let state = state else {
                    SwiftyBeaver.error(error ?? "")
                    safariMenuEnabled = false
                    group.leave()
                    return
                }
                
                safariMenuEnabled = state.isEnabled
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if !safariContentBlockerEnabled {
                // TODO: Show safari content blocker not enabled
                self.introViewOne.isHidden = false
                self.introViewTwo.isHidden = true
                self.AdBlockReadyView.isHidden = true
            } else if !safariMenuEnabled {
                // TODO: Show safari menu not enabled
                self.introViewOne.isHidden = false
                self.introViewTwo.isHidden = true
                self.AdBlockReadyView.isHidden = true
            } else if !UserPref.isLaunchAppOnUserLogin() && !self.skipLaunchAppOnUserLoginStep && safariContentBlockerEnabled && safariMenuEnabled {
                // TODO: Show intro screen
                self.introViewOne.isHidden = true
                self.introViewTwo.isHidden = false
                self.AdBlockReadyView.isHidden = true
            } else if (UserPref.isLaunchAppOnUserLogin() || self.skipLaunchAppOnUserLoginStep) && safariContentBlockerEnabled && safariMenuEnabled {
                // TODO: Show intro screen
                self.introViewOne.isHidden = true
                self.introViewTwo.isHidden = true
                self.AdBlockReadyView.isHidden = false
            }

            
            if !UserPref.isLaunchAppOnUserLogin() && !self.skipLaunchAppOnUserLoginStep {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                    self.checkExtensionIsEnabled()
                })
            }
        }
    }
    
    // Removed due to app rejection by Apple to use the in-app purchase
    /*private func openDonationPageInSafari() {
        if !NSWorkspace.shared.openFile(Constants.DONATION_PAGE_URL, withApplication: "Safari") {
            guard let url = URL(string: Constants.DONATION_PAGE_URL) else { return }
            NSWorkspace.shared.open(url)
        }
    }*/
    
    @IBAction func launchClick(_ sender: NSButton) {
        SFSafariApplication.showPreferencesForExtension(withIdentifier: Constants.SAFARI_CONTENT_BLOCKER_EXTENSION_IDENTIFIER, completionHandler: { (error) in
            if let error = error {
                SwiftyBeaver.error("safari extension preference error: \(error.localizedDescription)")
            } else {
                SwiftyBeaver.debug("safari extension preference opened")
            }
        })
    }
    
    @IBAction func startAppOnLoginClicked(_ sender: NSButton) {
        LogServerManager.shared.recordMessageWithUserID(msg: "start_app_on_login_clicked")
        let launcherAppId = "com.betafish.adblock-mac.LauncherApp"
        if !SMLoginItemSetEnabled(launcherAppId as CFString, sender.state == .on ? true : false) {
            SwiftyBeaver.error("Error in setting launcher app")
        } else {
            UserPref.setLaunchAppOnUserLogin(sender.state == .on)
        }
    }
    
    @IBAction func startSurfingWebClick(_ sender: NSButton) {
        // Removed due to app rejection by Apple to use the in-app purchase
        /*if !UserPref.isDonationPageShown() {
            self.openDonationPageInSafari()
        }*/
        self.delegate?.startApp()
        NSWorkspace.shared.launchApplication("Safari")
    }

    @IBAction func skipThisStepClicked(_ sender: NSButton) {
        LogServerManager.shared.recordMessageWithUserID(msg: "skip_this_step_clicked")
        self.skipLaunchAppOnUserLoginStep = true
         UserPref.setLaunchAppOnUserLogin(false)
    }
    
}

extension IntroVC : NSTextViewDelegate {
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
