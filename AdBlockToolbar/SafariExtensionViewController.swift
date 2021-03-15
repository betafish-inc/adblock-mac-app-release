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
    @IBOutlet weak var pauseProgressView: NSProgressIndicator!
    @IBOutlet weak var allowAdsProgressView: NSProgressIndicator!
    @IBOutlet weak var whitelistDomainStackView: NSStackView!
    @IBOutlet weak var btnWhitelistDomain: NSButton!
    @IBOutlet weak var whitelistDomainLine: NSBox!
    @IBOutlet weak var upgradeButton: Button!
    @IBOutlet weak var pauseImage: NSImageView!
    @IBOutlet weak var allowAdsImage: NSImageView!
    @IBOutlet weak var whitelistDomainImage: NSImageView!

    static let shared = SafariExtensionViewController()
   
    private var url: String?
    private var minSafariVersion11: Bool = true
    private var assetsManagerStatusObserverRef: Disposable?
    private let whitelistNotificationName = Notification.Name(rawValue: "\(Constants.SAFARI_MENU_EXTENSION_IDENTIFIER).whitelist")

    override func viewDidLoad() {
        super.viewDidLoad()

        DebugLog.configure()
        minSafariVersion11 = SFSafariServicesAvailable(SFSafariServicesVersion.version11_0)
        
        onPopoverVisible(with: url)
        
        assetsManagerStatusObserverRef =
            AssetsManager.shared.status.didChange.addHandler(target: self, handler: SafariExtensionViewController.assetsManagerStatusChangeObserver)
    }
    
    deinit {
        assetsManagerStatusObserverRef?.dispose()
    }
    
    private func assetsManagerStatusChangeObserver(data: (AssetsManagerStatus, AssetsManagerStatus)) {
        switch data.1 {
        case .mergeRulesStarted:
            DispatchQueue.main.async {[weak self] in
                guard let strongSelf = self else { return }
                strongSelf.allowAdsProgressView.isHidden = false
                strongSelf.allowAdsProgressView.startAnimation(nil)
            }
        case .mergeRulesCompleted, .mergeRulesError:
            DispatchQueue.main.async {[weak self] in
                guard let strongSelf = self else { return }
                strongSelf.allowAdsProgressView.stopAnimation(nil)
                strongSelf.allowAdsProgressView.isHidden = true
                strongSelf.updateWhitelistButtonTitle()
                strongSelf.btnAllowAds.isEnabled = true
                strongSelf.allowAdsImage.isEnabled = true
                strongSelf.reloadCurrentPage()
                FilterListsText.shared.processTextFromFile()
            }
        default:
            SwiftyBeaver.debug("idle")
        }
    }
    
    func onPopoverVisible(with url: String?) {
        DispatchQueue.main.async {[weak self] in
            self?.updatePopover(with: url)
        }
    }
    
    private func updatePopover(with url: String?) {
        self.url = url
        
        pauseProgressView.stopAnimation(nil)
        allowAdsProgressView.stopAnimation(nil)
        pauseProgressView.isHidden = true
        allowAdsProgressView.isHidden = true
        btnPause.isEnabled = true
        pauseImage.isEnabled = true
        
        updateWhitelistButtonTitle()
        updatePauseButtonTitle()
        
        if minSafariVersion11 {
            if PauseResumeBlockinManager.shared.isBlockingPaused() ||
                url == nil ||
                WhitelistManager.shared.isEnabled(url ?? "") ||
                !UserPref.isUpgradeUnlocked {
                btnWhitelistDomain.isEnabled = false
                whitelistDomainImage.isEnabled = false
            } else {
                btnWhitelistDomain.isEnabled = true
                whitelistDomainImage.isEnabled = true
            }
            
            upgradeButton.isHidden = UserPref.isUpgradeUnlocked
        } else {
            whitelistDomainStackView.isHidden = true
            whitelistDomainLine.isHidden = true
            upgradeButton.isHidden = true
            btnWhitelistDomain.isHidden = true
            whitelistDomainImage.isHidden = true
        }
        
        var enableAllowAds = true
        if PauseResumeBlockinManager.shared.isBlockingPaused() || url == nil {
            enableAllowAds = false
        }
        allowAdsImage.isEnabled = enableAllowAds
        btnAllowAds.isEnabled = enableAllowAds
    }
    
    private func updateWhitelistButtonTitle() {
        var messageKey = ""
        if let url = self.url, WhitelistManager.shared.isEnabled(url) {
            if minSafariVersion11 {
               messageKey = "block.ads.site.menu.safari.11"
            } else {
                messageKey = "block.ads.site.menu.safari.10"
            }
        } else if minSafariVersion11 {
            messageKey = "allow.ads.site.menu.safari.11"
        } else {
            messageKey = "allow.ads.site.menu.safari.10"
        }
        btnAllowAds.title = NSLocalizedString(messageKey, comment: "")
    }
    
    private func updatePauseButtonTitle() {
        let messageKey = PauseResumeBlockinManager.shared.isBlockingPaused() ? "resume.menu" : "pause.menu"
        btnPause.title = NSLocalizedString(messageKey, comment: "")
    }
    
    private func reloadCurrentPage() {
        SFSafariApplication.getActiveWindow { (window) in
            window?.getActiveTab { (tab) in
                tab?.getActivePage { (page) in
                    page?.reload()
                }
            }
        }
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
            DispatchQueue.main.async {[weak self] in
                guard let strongSelf = self else { return }
                strongSelf.pauseProgressView.stopAnimation(nil)
                strongSelf.pauseProgressView.isHidden = true
                strongSelf.updatePauseButtonTitle()
                strongSelf.btnPause.isEnabled = true
                strongSelf.pauseImage.isEnabled = true
                strongSelf.reloadCurrentPage()
            }
        }
    }
    
    @IBAction func addToWhitelistClick(_ sender: Any) {
        guard let url = self.url else { return }
        
        btnAllowAds.isEnabled = false
        allowAdsImage.isEnabled = false
        
        if !WhitelistManager.shared.updateCustomFilter(url) {
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
        if UserPref.isUpgradeUnlocked {
            if !(PauseResumeBlockinManager.shared.isBlockingPaused() || url == nil ||
                WhitelistManager.shared.isEnabled(url ?? "")) {
                WizardHelper.injectWizard()
            }
        } else {
            upgradeClick()
        }
    }
    
    private func upgradeClick() {
        NSWorkspace.shared.launchApplication("AdBlock")
    }
}
