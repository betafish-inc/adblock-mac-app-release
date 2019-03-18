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

import SafariServices
import SwiftyBeaver

class SafariExtensionViewController: SFSafariExtensionViewController {
    @IBOutlet weak var btnAllowAds: NSButton!
    @IBOutlet weak var btnPause: NSButton!
    @IBOutlet weak var btnSettings: NSButton!
    @IBOutlet weak var btnHelpAndFeedback: NSButton!
    @IBOutlet weak var disabledTextField: NSTextField!
    @IBOutlet weak var pauseProgressView: NSProgressIndicator!
    @IBOutlet weak var allowAdsProgressView: NSProgressIndicator!
    @IBOutlet weak var allowAdsStackView: NSStackView!
    @IBOutlet weak var allowAdsLine: NSBox!
    @IBOutlet weak var warningBox: NSBox!
    @IBOutlet weak var menuBox: NSBox!
    @IBOutlet weak var whitelistDomainStackView: NSStackView!
    @IBOutlet weak var btnWhitelistDomain: NSButton!
    @IBOutlet weak var whitelistDomainLine: NSBox!
    @IBOutlet weak var upgradeButton: ToolbarButton!
    @IBOutlet weak var pauseImage: NSImageView!
    @IBOutlet weak var allowAdsImage: NSImageView!
    @IBOutlet weak var whitelistDomainImage: NSImageView!

    fileprivate var assetsManagerStatusObserverRef: Disposable? = nil
    
    static let shared = SafariExtensionViewController()
    
    private var url: String?
    private var contentBlockerEnabled: Bool = true
    
    private let whitelistNotificationName = Notification.Name(rawValue: "\(Constants.SAFARI_MENU_EXTENSION_IDENTIFIER).whitelist")

    /// True if the application is in dark mode, and false otherwise
    var inDarkMode: Bool {
        let mode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
        return mode == "Dark"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if (Constants.DEBUG_LOG_ENABLED) {
            let console = ConsoleDestination()
            console.format = "$DHH:mm:ss$d $L: $M"
            console.minLevel = .verbose
            SwiftyBeaver.addDestination(console)
            if let assetsPath = Constants.AssetsUrls.assetsFolder?.path, FileManager.default.fileExists(atPath: assetsPath) {
                FileManager.default.createDirectoryIfNotExists(Constants.AssetsUrls.logFolder, withIntermediateDirectories: true)
                let file = FileDestination()
                file.logFileURL = Constants.AssetsUrls.logFileURL
                SwiftyBeaver.addDestination(file)
            }
        }
        
        onPopoverVisible(with: self.url)
        
        if (SFSafariServicesAvailable(SFSafariServicesVersion.version11_0)) {
            btnAllowAds.title = NSLocalizedString("allow.ads.site.menu.safari.11", comment: "")
        } else {
            btnAllowAds.title = NSLocalizedString("allow.ads.site.menu.safari.10", comment: "")
        }
        btnPause.title = NSLocalizedString("pause.menu", comment: "")
        btnSettings.title = NSLocalizedString("settings.menu", comment: "")
        btnHelpAndFeedback.title = NSLocalizedString("help.feedback.menu", comment: "")
        disabledTextField.stringValue = NSLocalizedString("extension.disabled.alert", comment: "")
        btnWhitelistDomain.title = NSLocalizedString("allow.ads.site.menu.safari.10", comment: "")
        upgradeButton.attributedTitle = NSAttributedString(string: NSLocalizedString("upgrade.button", comment: ""), attributes: upgradeButton.getAttributes())

        if #available(OSXApplicationExtension 10.14, *) {
            btnAllowAds.appearance =  NSAppearance(named: .aqua)
            allowAdsProgressView.appearance = NSAppearance(named: .aqua)
            btnPause.appearance =  NSAppearance(named: .aqua)
            pauseProgressView.appearance = NSAppearance(named: .aqua)
            btnSettings.appearance = NSAppearance(named: .aqua)
            btnHelpAndFeedback.appearance = NSAppearance(named: .aqua)
            btnWhitelistDomain.appearance = NSAppearance(named: .aqua)
        }
        
        assetsManagerStatusObserverRef = AssetsManager.shared.status.didChange.addHandler(target: self, handler: SafariExtensionViewController.assetsManagerStatusChangeObserver)
    }
    
    deinit {
        assetsManagerStatusObserverRef?.dispose()
    }
    
    private func observeContentBlockerState() {
        SFContentBlockerManager.getStateOfContentBlocker(withIdentifier: Constants.SAFARI_CONTENT_BLOCKER_EXTENSION_IDENTIFIER) { (state, error) in
            guard let state = state else {
                SwiftyBeaver.error("Content blocker state error:\(String(describing: error))")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.observeContentBlockerState()
                }
                return
            }
            SwiftyBeaver.debug("Content blocker state: \(state.isEnabled)")
            self.contentBlockerEnabled = state.isEnabled
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.observeContentBlockerState()
            }
        }
    }
    
    private func assetsManagerStatusChangeObserver(data: (AssetsManagerStatus, AssetsManagerStatus)) {
        
        switch data.1 {
        case .mergeRulesStarted:
            allowAdsProgressView.isHidden = false
            allowAdsProgressView.startAnimation(nil)
        case .mergeRulesCompleted, .mergeRulesError:
            DispatchQueue.main.asyncAfter(deadline: .now()+2, execute: {
                self.allowAdsProgressView.stopAnimation(nil)
                self.allowAdsProgressView.isHidden = true
                self.updateWhitelistButtonTitle()
                self.btnAllowAds.isEnabled = true
                self.allowAdsImage.isEnabled = true
                self.reloadCurrentPage()
                FilterListsText.shared.processTextFromFile()
            })
            
        default:
            SwiftyBeaver.debug("idle")
        }
    }
    
    func onPopoverVisible(with url: String?) {
        DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
            self.updatePopover(with: url)
        })
    }
    
    private func updatePopover(with url: String?) {
        self.url = url
        
        if self.contentBlockerEnabled {
            self.warningBox.isHidden = true
            self.menuBox.isHidden = false
            
            self.pauseProgressView.stopAnimation(nil)
            self.allowAdsProgressView.stopAnimation(nil)
            self.pauseProgressView.isHidden = true
            self.allowAdsProgressView.isHidden = true
            self.btnPause.isEnabled = true
            self.pauseImage.isEnabled = true
            
            self.updateWhitelistButtonTitle()
            self.updatePauseButtonTitle()
            
            if (SFSafariServicesAvailable(SFSafariServicesVersion.version11_0)) {
                if (PauseResumeBlockinManager.shared.isBlockingPaused() || self.url == nil || (WhitelistManager.shared.exists(self.url ?? "") && WhitelistManager.shared.isEnabled(self.url ?? ""))) {
                    self.btnWhitelistDomain.isEnabled = false
                    self.whitelistDomainImage.isEnabled = false
                } else {
                    self.btnWhitelistDomain.isEnabled = true
                    self.whitelistDomainImage.isEnabled = true
                }
                
                if (UserPref.isUpgradeUnlocked()) {
                    self.upgradeButton.isHidden = true
                } else {
                    self.upgradeButton.isHidden = false
                    self.btnWhitelistDomain.isEnabled = false
                    self.whitelistDomainImage.isEnabled = false
                }
            } else {
                self.whitelistDomainStackView.isHidden = true
                self.whitelistDomainLine.isHidden = true
                self.upgradeButton.isHidden = true
                self.btnWhitelistDomain.isHidden = true
                self.whitelistDomainImage.isHidden = true
            }
            
            if (PauseResumeBlockinManager.shared.isBlockingPaused() || self.url == nil) {
                self.allowAdsImage.isEnabled = false
                self.btnAllowAds.isEnabled = false
            } else {
                self.allowAdsImage.isEnabled = true
                self.btnAllowAds.isEnabled = true
            }
        } else {
            self.warningBox.isHidden = false
            self.menuBox.isHidden = true
        }
    }
    
    private func updateWhitelistButtonTitle() {
        guard let url = self.url else {
            if (SFSafariServicesAvailable(SFSafariServicesVersion.version11_0)) {
                btnAllowAds.title = NSLocalizedString("allow.ads.site.menu.safari.11", comment: "")
            } else {
                btnAllowAds.title = NSLocalizedString("allow.ads.site.menu.safari.10", comment: "")
            }
            return
        }
        if WhitelistManager.shared.exists(url) && WhitelistManager.shared.isEnabled(url) {
            if (SFSafariServicesAvailable(SFSafariServicesVersion.version11_0)) {
                btnAllowAds.title = NSLocalizedString("block.ads.site.menu.safari.11", comment: "")
            } else {
                btnAllowAds.title = NSLocalizedString("block.ads.site.menu.safari.10", comment: "")
            }
        } else {
            if (SFSafariServicesAvailable(SFSafariServicesVersion.version11_0)) {
                btnAllowAds.title = NSLocalizedString("allow.ads.site.menu.safari.11", comment: "")
            } else {
                btnAllowAds.title = NSLocalizedString("allow.ads.site.menu.safari.10", comment: "")
            }
        }
    }
    
    private func updatePauseButtonTitle() {
        if PauseResumeBlockinManager.shared.isBlockingPaused() {
            btnPause.title = NSLocalizedString("resume.menu", comment: "")
        } else {
            btnPause.title = NSLocalizedString("pause.menu", comment: "")
        }
    }
    
    private func reloadCurrentPage() {
        SFSafariApplication.getActiveWindow(completionHandler: { (window) in
            window?.getActiveTab(completionHandler: { (tab) in
                tab?.getActivePage(completionHandler: { (page) in
                    page?.reload()
                })
            })
        })
    }
    
    @IBAction func pauseBlockingClick(_ sender: Any) {
        if PauseResumeBlockinManager.shared.isBlockingPaused() {
            PauseResumeBlockinManager.shared.resumeBlocking()
        } else {
            PauseResumeBlockinManager.shared.pauseBlocking()
        }
        
        pauseProgressView.isHidden = false
        pauseProgressView.startAnimation(nil)
        btnPause.isEnabled = false
        pauseImage.isEnabled = false
        PauseResumeBlockinManager.shared.callReloadContentBlocker {
            let delay = TimeInterval(PauseResumeBlockinManager.shared.isBlockingPaused() ? 5 : 2)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: {
                self.pauseProgressView.stopAnimation(nil)
                self.pauseProgressView.isHidden = true
                self.updatePauseButtonTitle()
                self.btnPause.isEnabled = true
                self.pauseImage.isEnabled = true
                self.reloadCurrentPage()
            })
        }
    }
    
    @IBAction func addToWhitelistClick(_ sender: Any) {
        guard let url = self.url else {
            return
        }
        btnAllowAds.isEnabled = false
        allowAdsImage.isEnabled = false
        if WhitelistManager.shared.exists(url) {
            if WhitelistManager.shared.isEnabled(url) {
                WhitelistManager.shared.remove(url)
            } else {
                WhitelistManager.shared.enable(url)
            }
        } else if (WhitelistManager.shared.isValid(url: url)) {
            WhitelistManager.shared.add(url)
        } else {
            AlertUtil.errorAlert(title: NSLocalizedString("error.title", comment: ""),
                                 message: NSLocalizedString("invalid.url.alert", comment: ""))
            return
        }
        
        DistributedNotificationCenter.default().post(name: whitelistNotificationName,
                                                     object: Constants.SAFARI_MENU_EXTENSION_IDENTIFIER)
    }
    
    @IBAction func settingsClick(_ sender: Any) {
        NSWorkspace.shared.launchApplication("AdBlock")
    }
    
    @IBAction func helpAndFeedbackClick(_ sender: Any) {
        Util.openUrlInSafari(Constants.HELP_PAGE_URL)
    }
    
    @IBAction func whitelistDomainClick(_ sender: Any) {
        if (UserPref.isUpgradeUnlocked()) {
            if !(PauseResumeBlockinManager.shared.isBlockingPaused() || self.url == nil || (WhitelistManager.shared.exists(self.url ?? "") && WhitelistManager.shared.isEnabled(self.url ?? ""))) {
                whitelistWizardClick()
            }
        } else {
            upgradeClick()
        }
    }

    private func whitelistWizardClick() {
        let whitelistURL = Bundle.main.url(forResource:"whitelist_ui", withExtension: "js")
        let jqueryUiURL = Bundle.main.url(forResource:"jquery/jquery-ui.min", withExtension: "js")
        let jqueryURL = Bundle.main.url(forResource:"jquery/jquery-2.1.1.min", withExtension: "js")
        let jqueryUiCSSURL = Bundle.main.url(forResource:"jquery/css/jquery-ui", withExtension: "css")
        let jqueryOverrideCSSURL = Bundle.main.url(forResource:"jquery/css/override-page", withExtension: "css")

        let whitelistText = readFile(with: whitelistURL!)
        let jqueryUiText = readFile(with: jqueryUiURL!)
        let jqueryText = readFile(with: jqueryURL!)
        let jqueryUiCSSText = readFile(with: jqueryUiCSSURL!)
        let jqueryOverrideCSSText = readFile(with: jqueryOverrideCSSURL!)

        let locale = NSLocale.autoupdatingCurrent.languageCode!
        let localeFile = "_locales/" + locale + "/messages";
        var localeFileURL = Bundle.main.url(forResource:localeFile, withExtension: "json")
        if !FileManager.default.fileExists(atPath: (localeFileURL?.absoluteString)!) {
            localeFileURL = Bundle.main.url(forResource: "_locales/en/messages", withExtension: "json")
        }
        let localeMessageText = readFile(with: localeFileURL!)

        SFSafariApplication.getActiveWindow(completionHandler: { (window) in
            window?.getActiveTab(completionHandler: { (tab) in
                tab?.getActivePage(completionHandler: { (page) in
                    page?.dispatchMessageToScript(withName: "localeMessages", userInfo: ["localeMessages": localeMessageText, "topOnly": true ])
                    page?.dispatchMessageToScript(withName: "addCSS", userInfo: ["addCSS": jqueryUiCSSText, "topOnly": true ])
                    page?.dispatchMessageToScript(withName: "addCSS", userInfo: ["addCSS": jqueryOverrideCSSText, "topOnly": true ])
                    page?.dispatchMessageToScript(withName: "injectScript", userInfo: ["evalScript": jqueryText, "topOnly": true ])
                    page?.dispatchMessageToScript(withName: "injectScript", userInfo: ["evalScript": jqueryUiText, "topOnly": true ])
                    page?.dispatchMessageToScript(withName: "injectScript", userInfo: ["evalScript": whitelistText, "topOnly": true ])
                })
            })
        })
    }
    
    private func upgradeClick() {
        NSWorkspace.shared.launchApplication("AdBlock")
    }

    private func readFile(with url: URL)->String {
        do
        {
            return try String.init(contentsOf: url)
        }
        catch
        {
            return ""
        }
    }

}
