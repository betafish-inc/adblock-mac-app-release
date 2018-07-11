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
import SwiftyBeaver
import SafariServices

class MainVC: NSViewController {
    
    @IBOutlet weak var lblLastUpdated: NSTextField!
    @IBOutlet weak var filterListOptionsView: NSBox!
    @IBOutlet weak var whitelistOptionsView: NSBox!
    @IBOutlet weak var lblFilterlistDesc: NSTextField!
    @IBOutlet weak var lblWhitelistDesc: NSTextField!
    @IBOutlet weak var filterListProgress: NSProgressIndicator!
    @IBOutlet weak var txtWhitelist: NSTextField!
    @IBOutlet weak var rightPanel: NSBox!
    @IBOutlet weak var warningBox: NSBox!
    @IBOutlet weak var imgWarning: NSImageView!
    @IBOutlet weak var btnUpdateFilterLists: Button!
    @IBOutlet weak var btnAddWebsite: Button!
    @IBOutlet weak var whitelistExampleText: NSTextField!
    @IBOutlet weak var disabledAlertText: NSTextField!
    @IBOutlet weak var disabledButton: NSButton!
    
    fileprivate var sectionListVC: SectionListVC? = nil
    fileprivate var sectionDetailVC: SectionDetailVC? = nil
    fileprivate var lastUpdatedDate: Date? = nil
    fileprivate var lastUpdatedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = NSLocale.current
        formatter.dateFormat = "MMM dd, yyyy HH:mm a zzz"
        return formatter
    }()
    
    fileprivate var assetsManagerStatusObserverRef: Disposable? = nil
    
    fileprivate var updatingFilterLists = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.appMenuBar.initializeAppMenuBar()
        }
        PingDataManager.shared.start()
        
        lastUpdatedDate = UserPref.filterListsUpdatedDate()
        updateLastUpdatedDateLabel()
        assetsManagerStatusObserverRef = AssetsManager.shared.status.didChange.addHandler(target: self, handler: MainVC.assetsManagerStatusChageObserver)
        notifyIfAnyExtensionIsDisabledAndDayChanged()
        showOrHideExtensionWarning()
        scheduleFilterUpdate()
        
        lblFilterlistDesc.stringValue = NSLocalizedString("filter.lists.header", comment: "")
        lblWhitelistDesc.stringValue = NSLocalizedString("whitelisting.header", comment: "")
        btnUpdateFilterLists.attributedTitle = NSAttributedString(string: NSLocalizedString("filter.lists.update.button", comment: ""), attributes: btnUpdateFilterLists.attributedTitle.attributes(at: 0, effectiveRange: nil))
        txtWhitelist.placeholderString = NSLocalizedString("whitelisting.example.text", comment: "")
        btnAddWebsite.attributedTitle = NSAttributedString(string: NSLocalizedString("whitelisting.button", comment: ""), attributes: btnAddWebsite.attributedTitle.attributes(at: 0, effectiveRange: nil))
        whitelistExampleText.stringValue = NSLocalizedString("whitelisting.example.explanation", comment: "")
        disabledAlertText.stringValue = NSLocalizedString("adblock.disabled.alert", comment: "")
        disabledButton.title = NSLocalizedString("adblock.disabled.button", comment: "")
    }
    
    deinit {
        assetsManagerStatusObserverRef?.dispose()
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier?.rawValue == "SectionListVC" {
            self.sectionListVC = segue.destinationController as? SectionListVC
            self.sectionListVC?.delegate = self
        } else if segue.identifier?.rawValue == "SectionDetailVC" {
            self.sectionDetailVC = segue.destinationController as? SectionDetailVC
            self.sectionListVC?.delegate = self
        }
    }
    
    fileprivate func assetsManagerStatusChageObserver(data: (AssetsManagerStatus, AssetsManagerStatus)) {
        switch data.1 {
        case .filterUpdateStarted:
            updatingFilterLists = true
            filterListProgress.startAnimation(nil)
            
        case .filterUpdateError:
            let errorMessage = NSLocalizedString("filter.lists.error", comment: "")
            AlertUtil.toast(in: rightPanel, message: errorMessage, toastType: .error)
            updatingFilterLists = false
            
        case .mergeRulesStarted:
            txtWhitelist.isEnabled = false
            if updatingFilterLists {
                filterListProgress.startAnimation(nil)
            }
            
        case .mergeRulesCompleted:
            if updatingFilterLists {
                lastUpdatedDate = Date()
                self.updateLastUpdatedDateLabel()
                let message = NSLocalizedString("filter.lists.success", comment: "")
                AlertUtil.displayNotification(title: NSLocalizedString("filter.lists.title", comment: ""), message: message)
                AlertUtil.toast(in: rightPanel, message: message)
                FilterListManager.shared.updateRulesCount(completion: { (successful) in
                    SwiftyBeaver.debug("[MAIN_VC]: Rules count updated")
                })
                updatingFilterLists = false
            }
            txtWhitelist.isEnabled = true
        
        case .mergeRulesError:
            updatingFilterLists = false
            txtWhitelist.isEnabled = true
            
        default:
            filterListProgress.stopAnimation(nil)
        }
    }
    
    private func updateLastUpdatedDateLabel() {
        lblLastUpdated.stringValue = "\(NSLocalizedString("filter.lists.last.updated", comment: "")) \(lastUpdatedDateFormatter.string(from: lastUpdatedDate!))"
        UserPref.setFilterListsUpdatedDate(lastUpdatedDate!)
    }
    
    private func notifyIfAnyExtensionIsDisabledAndDayChanged() {
        // commented out due to a bug that reports the extension & content blocker(s) as disabled when the computer goes to sleep
        /**
        Util.fetchExtensionStatus { (contentBlockerEnabled, menuEnabled, error) in
            
            if (contentBlockerEnabled && menuEnabled) || (error != nil) {
                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 60, execute: self.notifyIfAnyExtensionIsDisabledAndDayChanged)
                return
            }
            
            let lastNotifiedDate = UserPref.lastNotifiedDateForDisabledExtension()
            let currentDate = Date()
            var showNotification = false
            if lastNotifiedDate == nil {
                showNotification = true
            } else {
                let minuteDiff = Calendar.current.dateComponents([.minute], from: lastNotifiedDate ?? currentDate, to: currentDate).minute ?? 0
                showNotification = minuteDiff >= Constants.SAFARI_EXTENSION_DISABLED_NOTIFICATION_DELAY_IN_MINUTES
            }
            
            if showNotification {
                let app = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!).first
                if app?.isActive ?? false {
                    // do nothing
                } else {
                    let message = NSLocalizedString("adblock.disabled.alert", comment: "")
                    AlertUtil.displayNotification(title: NSLocalizedString("adblock.extension", comment: ""),
                                                  message: message)
                    UserPref.setLastNotifiedDateForDisabledExtension(currentDate)
                }
            }
            
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + (10 * 60), execute: self.notifyIfAnyExtensionIsDisabledAndDayChanged)
        }
        */
    }
    
    private func showOrHideExtensionWarning() {
        Util.fetchExtensionStatus { (contentBlockerEnabled, menuEnabled, error) in
            if error == nil {
                self.warningBox.animator().isHidden = contentBlockerEnabled
            }
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 3, execute: self.showOrHideExtensionWarning)
        }
    }
    
    private func scheduleFilterUpdate() {
        let lastFilterUpdateDate = UserPref.filterListsUpdatedDate()
        let currentDate = Date()
        let nextFilterUpdateDate: Date = {
            if lastFilterUpdateDate == Constants.BUNDLED_FILTER_LISTS_UPDATE_DATE {
                return lastFilterUpdateDate + TimeInterval(60 * 60) // 1 hour after the last updated date bundled with the app
            } else {
                return lastFilterUpdateDate + TimeInterval(Constants.FILTER_LISTS_UPDATE_SCHEDULE_INTERVAL_IN_SECONDS)
            }
        }()
        if currentDate >= nextFilterUpdateDate {
            DispatchQueue.main.async { AssetsManager.shared.requestFilterUpdate() }
        }
        // check after 4 hours
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + (60 * 60 * 4), execute: self.scheduleFilterUpdate)
    }
    
    @IBAction func updateFilterListButtonClicked(_ sender: Button) {
        AssetsManager.shared.requestFilterUpdate()
    }

    @IBAction func addWebsiteButtonClicked(_ sender: Button) {
        if txtWhitelist.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).count == 0 {
            return
        }
        
        guard WhitelistManager.shared.isValid(url: txtWhitelist.stringValue) else {
            let errorMessage = NSLocalizedString("whitelisting.enter.valid.url", comment: "")
            AlertUtil.toast(in: rightPanel, message: errorMessage, toastType: .error)
            return
        }
        
        guard !WhitelistManager.shared.exists(txtWhitelist.stringValue) else {
            let errorMessage = NSLocalizedString("whitelisting.url.exists", comment: "")
            AlertUtil.toast(in: rightPanel, message: errorMessage, toastType: .error)
            return
        }
        
        sectionDetailVC?.onWhitelisting(url: WhitelistManager.shared.normalizeUrl(txtWhitelist.stringValue))
        WhitelistManager.shared.add(txtWhitelist.stringValue)
        txtWhitelist.stringValue = ""
    }
    
    @IBAction func AdBlockLogoClicked(_ sender: Any) {
        if !NSWorkspace.shared.openFile(Constants.ADBLOCK_WEBSITE_URL, withApplication: "Safari") {
            guard let url = URL(string: Constants.ADBLOCK_WEBSITE_URL) else { return }
            NSWorkspace.shared.open(url)
        }
    }
    
    @IBAction func activateExtensionButtonClicked(_ sender: Any) {
        
        SFSafariApplication.showPreferencesForExtension(withIdentifier: Constants.SAFARI_CONTENT_BLOCKER_EXTENSION_IDENTIFIER, completionHandler: { (error) in
            if let error = error {
                SwiftyBeaver.error("safari extension preference error: \(error.localizedDescription)")
            } else {
                SwiftyBeaver.debug("safari extension preference opened")
            }
        })
    }
}

extension MainVC : SectionListVCDelegate {
    func sectionListVC(_ vc: SectionListVC, didSelectSectionItem item: Item) {
        switch item.id ?? "" {
        case Item.WHITELIST_ITEM_ID:
            item.filterListItems = WhitelistManager.shared.getAllItems()
            whitelistOptionsView.isHidden = false
            lblWhitelistDesc.isHidden = false
            filterListOptionsView.isHidden = true
            lblFilterlistDesc.isHidden = true
            txtWhitelist.becomeFirstResponder()
        default:
            whitelistOptionsView.isHidden = true
            lblWhitelistDesc.isHidden = true
            filterListOptionsView.isHidden = false
            lblFilterlistDesc.isHidden = false
        }
        sectionDetailVC?.updateItems(item.filterListItems, title: item.name ?? "", itemId: item.id ?? "")
    }
}

extension MainVC : SectionDetailVCDelegate {
    func onTooManyRulesActiveError() {
        let message = NSLocalizedString("filter.lists.too.many.rules", comment: "")
        AlertUtil.toast(in: rightPanel, message: message, toastType: .error)
    }
}
