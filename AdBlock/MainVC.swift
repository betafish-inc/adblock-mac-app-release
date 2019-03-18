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
import SwiftyStoreKit
import StoreKit

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

    @IBOutlet weak var upgradeAndMyAccountView: NSView!

    @IBOutlet weak var upgradeView: NSView!
    @IBOutlet weak var upgradeLinePointFiveText: NSTextField!
    @IBOutlet weak var upgradeLinePointFiveDescription: NSTextField!
    @IBOutlet weak var upgradeLineOneText: NSTextField!
    @IBOutlet weak var upgradeLineOneDescription: NSTextField!
    @IBOutlet weak var upgradeLineTwoText: NSTextField!
    @IBOutlet weak var upgradeLineTwoDescription: NSTextField!
    @IBOutlet weak var upgradeNowButton: Button!
    @IBOutlet weak var upgradeRestore: NSTextField!
    @IBOutlet weak var upgradeClickHere: NSTextField!
    @IBOutlet weak var getMoreText: NSTextField!
    @IBOutlet weak var getMoreDescription: NSTextField!
    
    @IBOutlet weak var myAccountView: NSView!
    @IBOutlet weak var purchaseTitle: NSTextField!
    @IBOutlet weak var purchaseDescription: NSTextField!
    @IBOutlet weak var purchaseInfo: NSTextField!
    
    @IBOutlet weak var upgradeUnavailableView: NSView!
    @IBOutlet weak var upgradeUnavailableTitle: NSTextField!
    @IBOutlet weak var upgradeUnavailableDescription: NSTextField!
    
    fileprivate var sectionListVC: SectionListVC? = nil
    fileprivate var sectionDetailVC: SectionDetailVC? = nil
    fileprivate var lastUpdatedDate: Date? = nil
    fileprivate var lastUpdatedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = NSLocale.current
        formatter.dateFormat = "MMM dd, yyyy HH:mm a zzz"
        return formatter
    }()

    fileprivate let numberFormatter = NumberFormatter()

    fileprivate var upgradeProduct:SKProduct? = nil
    
    fileprivate var assetsManagerStatusObserverRef: Disposable? = nil
    
    fileprivate var updatingFilterLists = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.appMenuBar.initializeAppMenuBar()
        }

        if (!SFSafariServicesAvailable(SFSafariServicesVersion.version11_0) || !SKPaymentQueue.canMakePayments()) {
            setupUpdateBeforeUpgrade()
        } else if (UserPref.purchasedProductId() != nil) {
            setupMyAccount()
        } else {
            setupUpgrade()
        }
        
        lastUpdatedDate = UserPref.filterListsUpdatedDate()
        updateLastUpdatedDateLabel()
        assetsManagerStatusObserverRef = AssetsManager.shared.status.didChange.addHandler(target: self, handler: MainVC.assetsManagerStatusChageObserver)
        notifyIfAnyExtensionIsDisabledAndDayChanged()
        showOrHideExtensionWarning()
        scheduleFilterUpdate()
        
        lblFilterlistDesc.stringValue = NSLocalizedString("filter.lists.header", comment: "")
        lblWhitelistDesc.stringValue = NSLocalizedString("whitelisting.header", comment: "")
        btnUpdateFilterLists.attributedTitle = NSAttributedString(string: NSLocalizedString("filter.lists.update.button", comment: ""), attributes: btnUpdateFilterLists.getAttributes())
        txtWhitelist.placeholderString = NSLocalizedString("whitelisting.example.text", comment: "")
        btnAddWebsite.attributedTitle = NSAttributedString(string: NSLocalizedString("whitelisting.button", comment: ""), attributes: btnAddWebsite.getAttributes())
        whitelistExampleText.stringValue = NSLocalizedString("whitelisting.example.explanation", comment: "")
        disabledAlertText.stringValue = NSLocalizedString("adblock.disabled.alert", comment: "")
        disabledButton.title = NSLocalizedString("adblock.disabled.button", comment: "")

        upgradeLinePointFiveText.stringValue = NSLocalizedString("upgrade.line.point.five.text", comment: "")
        upgradeLinePointFiveDescription.stringValue = NSLocalizedString("upgrade.line.point.five.description", comment: "")
        upgradeLineOneText.stringValue = NSLocalizedString("upgrade.line.one.text", comment: "")
        upgradeLineOneDescription.stringValue = NSLocalizedString("upgrade.line.one.description", comment: "")
        upgradeLineTwoText.stringValue = NSLocalizedString("upgrade.line.two.text", comment: "")
        upgradeLineTwoDescription.stringValue = NSLocalizedString("upgrade.line.two.description", comment: "")
        upgradeNowButton.attributedTitle = NSAttributedString(string: NSLocalizedString("upgrade.now.button", comment: ""), attributes: upgradeNowButton.getAttributes())
        getMoreText.stringValue = NSLocalizedString("upgrade.get.more", comment: "")
        upgradeRestore.stringValue = NSLocalizedString("upgrade.already", comment: "")
        upgradeClickHere.stringValue = NSLocalizedString("upgrade.click.here", comment: "")
        
        if (!SFSafariServicesAvailable(SFSafariServicesVersion.version11_0)) {
            upgradeUnavailableTitle.stringValue = NSLocalizedString("upgrade.unavailable.version.title", comment: "")
            upgradeUnavailableDescription.stringValue = NSLocalizedString("upgrade.unavailable.version.desc", comment: "")
        } else {
            upgradeUnavailableTitle.stringValue = NSLocalizedString("upgrade.unavailable.unauthorized.title", comment: "")
            upgradeUnavailableDescription.stringValue = NSLocalizedString("upgrade.unavailable.unauthorized.desc", comment: "")
        }

        if #available(OSX 10.14, *) {
            lblLastUpdated.appearance = NSAppearance(named: .aqua)
            lblFilterlistDesc.appearance =  NSAppearance(named: .aqua)
            lblWhitelistDesc.appearance =  NSAppearance(named: .aqua)
            txtWhitelist.appearance =  NSAppearance(named: .aqua)
            btnUpdateFilterLists.appearance =  NSAppearance(named: .aqua)
            whitelistExampleText.appearance =  NSAppearance(named: .aqua)
            disabledAlertText.appearance =  NSAppearance(named: .aqua)
            lblLastUpdated.appearance =  NSAppearance(named: .aqua)
            disabledButton.appearance =  NSAppearance(named: .aqua)
            filterListProgress.appearance = NSAppearance(named: .aqua)
            upgradeLinePointFiveText.appearance = NSAppearance(named: .aqua)
            upgradeLinePointFiveDescription.appearance = NSAppearance(named: .aqua)
            upgradeLineOneText.appearance = NSAppearance(named: .aqua)
            upgradeLineOneDescription.appearance = NSAppearance(named: .aqua)
            upgradeLineTwoText.appearance = NSAppearance(named: .aqua)
            upgradeLineTwoDescription.appearance = NSAppearance(named: .aqua)
            upgradeNowButton.appearance = NSAppearance(named: .aqua)
            getMoreText.appearance = NSAppearance(named: .aqua)
            upgradeRestore.appearance = NSAppearance(named: .aqua)
            upgradeClickHere.appearance = NSAppearance(named: .aqua)
            getMoreDescription.appearance = NSAppearance(named: .aqua)
            purchaseTitle.appearance = NSAppearance(named: .aqua)
            purchaseDescription.appearance = NSAppearance(named: .aqua)
            purchaseInfo.appearance = NSAppearance(named: .aqua)
            upgradeUnavailableTitle.appearance = NSAppearance(named: .aqua)
            upgradeUnavailableDescription.appearance = NSAppearance(named: .aqua)
        }
    }
    
    deinit {
        assetsManagerStatusObserverRef?.dispose()
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == "SectionListVC" {
            self.sectionListVC = segue.destinationController as? SectionListVC
            self.sectionListVC?.delegate = self
        } else if segue.identifier == "SectionDetailVC" {
            self.sectionDetailVC = segue.destinationController as? SectionDetailVC
            self.sectionListVC?.delegate = self
        }
    }
    
    fileprivate func assetsManagerStatusChageObserver(data: (AssetsManagerStatus, AssetsManagerStatus)) {
        switch data.1 {
        case .filterUpdateStarted:
            updatingFilterLists = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                    self.filterListProgress.startAnimation(nil)
                })
            
        case .filterUpdateError:
            let errorMessage = NSLocalizedString("filter.lists.error", comment: "")
            AlertUtil.toast(in: rightPanel, message: errorMessage, toastType: .error)
            updatingFilterLists = false
            
        case .filterUpdateCompletedNoChange:
            if updatingFilterLists {
                updatingFilterLists = false
                lastUpdatedDate = Date()
                self.updateLastUpdatedDateLabel()
                let message = NSLocalizedString("filter.lists.success", comment: "")
                AlertUtil.displayNotification(title: NSLocalizedString("filter.lists.title", comment: ""), message: message)
                AlertUtil.toast(in: rightPanel, message: message)
            }
            
        case .mergeRulesStarted:
            DispatchQueue.main.async{
                self.txtWhitelist.isEnabled = false
            }
            if updatingFilterLists {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                        self.filterListProgress.startAnimation(nil)
                    })
            }
            
        case .mergeRulesCompleted:
            if updatingFilterLists {
                updatingFilterLists = false
                lastUpdatedDate = Date()
                self.updateLastUpdatedDateLabel()
                let message = NSLocalizedString("filter.lists.success", comment: "")
                AlertUtil.displayNotification(title: NSLocalizedString("filter.lists.title", comment: ""), message: message)
                AlertUtil.toast(in: rightPanel, message: message)
                FilterListManager.shared.updateRulesCount(completion: { (successful) in
                    SwiftyBeaver.debug("[MAIN_VC]: Rules count updated")
                })
            }
            txtWhitelist.isEnabled = true
        
        case .mergeRulesError:
            updatingFilterLists = false
            txtWhitelist.isEnabled = true
            
        default:
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                    self.filterListProgress.stopAnimation(nil)
                })
        }
    }
    
    private func updateLastUpdatedDateLabel() {
        lblLastUpdated.stringValue = "\(NSLocalizedString("filter.lists.last.updated", comment: "")) \(lastUpdatedDateFormatter.string(from: lastUpdatedDate ?? Date()))"
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
        
        guard !WhitelistManager.shared.exists(txtWhitelist.stringValue, exactMatch: true) else {
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
    
    @IBAction func restorePurchaseClicked(_ sender: Any) {
        SwiftyBeaver.debug("restore clicked")
        IAPManager.shared.restorePurchases ({ (error, purchases) in
            if let error = error {
                switch error {
                case .restorePurchaseFailed:
                    SwiftyBeaver.debug("Restore purchase failed.")
                default:
                    SwiftyBeaver.debug("Remaining error cases aren't used for restore purchase.")
                }
                self.alertUserAndReload(titleKey: "restore.failed.title", messageKey: "restore.failed.message")
                return
            }
            
            IAPManager.shared.validateReceipt({ (error, parsedReceipt) in
                if let error = error {
                    switch error {
                    case .receiptValidationFailed(let errMessage):
                        SwiftyBeaver.error(" receiptValidationFailed: \(errMessage)")
                    default:
                        SwiftyBeaver.error("Unknown receipt validation error: \(error)")
                    }
                    self.alertUserAndReload(titleKey: "restore.receipt.error.title", messageKey: "restore.receipt.error.message")
                    return
                }
                
                for purchase in purchases ?? [] {
                    SwiftyBeaver.debug(" \(purchase.productId)")
                    
                    if (self.upgradeProduct?.productIdentifier == purchase.productId) {
                        UserPref.setPurchasedProductId(purchase.productId)
                        UserPref.setUpgradeUnlocked(true)
                        SwiftyBeaver.debug(" Purchase successful")
                        LogServerManager.shared.recordMessageWithUserID(msg: "purchase_restored")
    
                        // Purchase successful, give feedback to user
                        self.alertUserAndReload(titleKey: "purchase.restore.title", messageKey: "purchase.restore.message")
                        self.setupMyAccount()
                        UserDefaults.standard.set(true, forKey: Constants.ANTICIRCUMVENTION_NOT_FIRST_RUN)
                        FilterListManager.shared.enable(filterListId: Constants.ANTI_CIRCUMVENTION_LIST_ID)
                        FilterListManager.shared.callAssetMerge()
                        return
                    }
                }
                SwiftyBeaver.debug("No matching purchases found")
                self.alertUserAndReload(titleKey: "restore.no.match.title", messageKey: "restore.no.match.message")
            })
        })
    }

    @IBAction func upgradeNowButtonClicked(_ sender: Any) {
        upgradeNowClickHandler(0)
    }
    
    private func upgradeNowClickHandler(_ retryCount: Int) {
        if let prodID = self.upgradeProduct?.productIdentifier {
            IAPManager.shared.purchase(product: prodID) { (error, purchase) in
                // Handle purchase error
                if let error = error {
                    switch error {
                    case .other(let err):
                        SwiftyBeaver.error("Error in purchase: \(err)")
                        self.alertUserAndReload(titleKey: "purchase.error.title", messageKey: "purchase.error.message", errorMessage: err.localizedDescription)
                    case .paymentFailed(let skErrorCode):
                        SwiftyBeaver.error("Payment failed error: \(skErrorCode)")
                        let errorMsg = "\(skErrorCode)"
                        self.alertUserAndReload(titleKey: "purchase.fail.title", messageKey: "purchase.fail.message", errorMessage: errorMsg)
                    case .cancelledPurchase:
                        SwiftyBeaver.debug("User has cancelled the purchase")
                        self.alertUserAndReload(titleKey: "purchase.cancelled.title", messageKey: "purchase.cancelled.message")
                    case .invalidIdentifiers(let identifier):
                        SwiftyBeaver.debug("Invalid IAP identifier: \(identifier)")
                        self.alertUserAndReload(titleKey: "purchase.id.invalid.title", messageKey: "purchase.id.invalid.message")
                    default:
                        SwiftyBeaver.debug("Remaining error cases aren't used for purchase.")
                    }
                    return
                }

                // Receipt validation
                IAPManager.shared.validateReceipt({ (error, parsedReceipt) in
                    // Handle receipt validation error
                    if let error = error {
                        switch error {
                        case .receiptValidationFailed(let errMessage):
                            SwiftyBeaver.error(" receiptValidationFailed: \(errMessage)")
                        default:
                            SwiftyBeaver.error("Unknown receipt validation error: \(error)")
                        }
                        self.alertUserAndReload(titleKey: "receipt.fail.title", messageKey: "receipt.fail.message")
                        return
                    }
                    
                    UserPref.setPurchasedProductId((self.upgradeProduct?.productIdentifier) ?? "missing.identifier")
                    UserPref.setUpgradeUnlocked(true)
                    SwiftyBeaver.debug(" Purchase successful")
                    
                    let timeDiff = parsedReceipt?.receiptCreationDate?.timeIntervalSince(parsedReceipt?.inAppPurchaseReceipts?[0].originalPurchaseDate ?? (Date.init(timeIntervalSinceNow: 1000)))
                    SwiftyBeaver.debug(" timeDiff: \(timeDiff)")
                    if (abs(timeDiff ?? 0) > 10.0) {
                        LogServerManager.shared.recordMessageWithUserID(msg: "purchase_restored")
                    } else {
                        LogServerManager.shared.recordMessageWithUserID(msg: "upgrade_purchased")
                    }
                    
                    // Purchase successful, give feedback to user
                    self.alertUserAndReload(titleKey: "purchase.thankyou.title", messageKey: "purchase.thankyou.message")
                    
                    self.setupMyAccount()
                    UserDefaults.standard.set(true, forKey: Constants.ANTICIRCUMVENTION_NOT_FIRST_RUN)
                    FilterListManager.shared.enable(filterListId: Constants.ANTI_CIRCUMVENTION_LIST_ID)
                    FilterListManager.shared.callAssetMerge()
                })
            }
        } else if retryCount == 0 {
            SwiftyBeaver.debug("Retrying loadProduct in upgradeNowClickHandler")
            self.loadProduct()
            self.upgradeNowClickHandler(1)
        }
    }
    
    private func alertUserAndReload(titleKey: String, messageKey: String, errorMessage: String? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            let message = NSLocalizedString(messageKey, comment: "") + (errorMessage ?? "")
            AlertUtil.displayNotification(title: NSLocalizedString(titleKey, comment: ""), message: message)
            AlertUtil.toast(in: self.rightPanel, message: message)
            self.sectionListVC?.reload()
        })
    }

    private func setupUpgrade() {
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.numberStyle = .currency
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            self.upgradeView.isHidden = false
            self.myAccountView.isHidden = true
            self.upgradeUnavailableView.isHidden = true
            self.loadProduct()
        })
    }

    private func setupMyAccount() {
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.numberStyle = .currency
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            self.upgradeView.isHidden = true
            self.myAccountView.isHidden = false
            self.upgradeUnavailableView.isHidden = true
            self.loadProduct()
        })
    }
    
    private func setupUpdateBeforeUpgrade() {
        upgradeView.isHidden = true
        myAccountView.isHidden = true
        upgradeUnavailableView.isHidden = false
    }

    private func loadProduct() {
        IAPManager.shared.fetchProducts(with: [Constants.Donate.onetimePurchaseAt499.rawValue])
        { (error, products) in
            guard let products = products else {
                SwiftyBeaver.debug("Something went wrong in retrieving product information.")
                self.alertUserAndReload(titleKey: "load.product.fail.title", messageKey: "load.product.fail.message")
                return
            }
            
            SwiftyBeaver.debug("products \(products.count)")
            for product in products {
                SwiftyBeaver.debug("product  \(product.productIdentifier) \(product.contentVersion) \(product.localizedPrice) \(product.localizedDescription)  \(product.localizedTitle) ")
            }

            self.upgradeProduct = products.filter{ $0.productIdentifier == Constants.Donate.onetimePurchaseAt499.rawValue }.first
            guard let upgradeProduct = self.upgradeProduct else {
                return
            }
            self.numberFormatter.locale = upgradeProduct.priceLocale
            self.numberFormatter.currencySymbol = upgradeProduct.priceLocale.currencySymbol
            let formattedPrice = "<b>" + (self.numberFormatter.string(from: upgradeProduct.price) ?? "$4.99") + "</b>"
            let myString = String(format: NSLocalizedString("upgrade.only", comment: ""), formattedPrice) + ". " + NSLocalizedString("upgrade.more.soon", comment: "")
            self.getMoreDescription.attributedStringValue = myString.convertHTML(size: 15)
            self.upgradeNowButton.isEnabled = true
            
            self.purchaseTitle.stringValue = upgradeProduct.localizedTitle
            self.purchaseDescription.stringValue = upgradeProduct.localizedDescription
        }
        if (UserPref.purchasedProductId() != nil){
            let receiptValidator = ReceiptValidator()
            let validationResult = receiptValidator.validateReceipt()
            switch validationResult {
            case .success(let parsedReceipt):
                self.purchaseInfo.stringValue = NSLocalizedString("purchase.date", comment: "") + DateFormatter.localizedString(from: parsedReceipt.inAppPurchaseReceipts?[0].originalPurchaseDate ?? Date.init(), dateStyle: DateFormatter.Style.long, timeStyle: DateFormatter.Style.long)
            case .error(let error):
                SwiftyBeaver.debug("  validateReceipt error \(error)")
            }
        
        } else {
            self.purchaseInfo.stringValue = NSLocalizedString("purchase.date", comment: "")
        }
    }

}

extension MainVC : SectionListVCDelegate {
    func sectionListVC(_ vc: SectionListVC, didSelectSectionItem item: Item) {
         SwiftyBeaver.debug("[sectionListVCDelegate] item \(item.id)")
        switch item.id ?? "" {
        case Item.WHITELIST_ITEM_ID:
            item.filterListItems = WhitelistManager.shared.getAllItems()
            whitelistOptionsView.isHidden = false
            lblWhitelistDesc.isHidden = false
            filterListOptionsView.isHidden = true
            lblFilterlistDesc.isHidden = true
            upgradeAndMyAccountView.isHidden = true
            txtWhitelist.becomeFirstResponder()
        case Item.UPGRADE_ITEM_ID:
            whitelistOptionsView.isHidden = true
            lblWhitelistDesc.isHidden = true
            filterListOptionsView.isHidden = true
            lblFilterlistDesc.isHidden = true
            upgradeAndMyAccountView.isHidden = false
        default:
            whitelistOptionsView.isHidden = true
            lblWhitelistDesc.isHidden = true
            filterListOptionsView.isHidden = false
            lblFilterlistDesc.isHidden = false
            upgradeAndMyAccountView.isHidden = true
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
