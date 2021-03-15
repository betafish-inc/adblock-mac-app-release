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
import WebKit
import SwiftyStoreKit
import StoreKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    var mainWindow: NSWindow?
    
    @IBOutlet weak var appMenuBar: AppMenuBar!
    
    func applicationWillFinishLaunching(_ aNotification: Notification) {
        DebugLog.configure()
    }
        
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        AssetsManager.shared.initialize()
        FilterListManager.shared.initialize()
        PingDataManager.shared.start()
        IAPManager.shared.initialize()

        if UserPref.purchasedProductId != nil {
            let receiptValidator = ReceiptValidator()
            let validationResult = receiptValidator.validateReceipt()
            switch validationResult {
            case .success(let parsedReceipt):
                SwiftyBeaver.debug("  validateReceipt success")
                // Enable app features
                let productID = Constants.Donate(rawValue: parsedReceipt.inAppPurchaseReceipts?[0].productIdentifier ?? "")
                switch productID {
                case .onetimePurchaseAt499?:
                    SwiftyBeaver.debug("PURCHASE VALIDATED")
                    UserPref.setUpgradeUnlocked(true)
                    if !UserDefaults.standard.bool(forKey: Constants.ANTICIRCUMVENTION_NOT_FIRST_RUN) {
                        UserDefaults.standard.set(true, forKey: Constants.ANTICIRCUMVENTION_NOT_FIRST_RUN)
                        FilterListManager.shared.enable(filterListId: Constants.ANTI_CIRCUMVENTION_LIST_ID)
                        FilterListManager.shared.callAssetMerge()
                    }
                case .none:
                    SwiftyBeaver.debug("Product ID from receipt doesn't match")
                    UserPref.setUpgradeUnlocked(false)
                }
            case .error(let error):
                SwiftyBeaver.error("  validateReceipt error \(error)")
            }
        }
    }
    
    func isWindowOpen() -> Bool {
        let windowsOpen = NSApplication.shared.windows
        if windowsOpen.count >= 1 {
            return windowsOpen[0].isVisible ? true : windowsOpen[0].isMiniaturized
        } else {
            return false
        }
    }
    
    @IBAction func helpMenuClick(_ sender: Any) {
        if !NSWorkspace.shared.openFile(Constants.HELP_PAGE_URL, withApplication: "Safari") {
            guard let url = URL(string: Constants.HELP_PAGE_URL) else { return }
            NSWorkspace.shared.open(url)
        }
    }
    
    @IBAction func newWindowClick(_ sender: Any) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let mainWC = storyboard.instantiateController(withIdentifier: "MainWC") as? NSWindowController else { return }
        mainWC.showWindow(nil)
        NSApp.setActivationPolicy(.regular)
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(newWindowClick) {
            return !isWindowOpen()
        }
        return true
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            newWindowClick(self)
        }
        return true
    }
}

@available(OSX 10.13.2, *)
extension SKProduct.PeriodUnit {
    func description(capitalizeFirstLetter: Bool = false, numberOfUnits: Int? = nil) -> String {
        let period: String = {
            switch self {
            case .day: return "day"
            case .week: return "week"
            case .month: return "month"
            case .year: return "year"
            }
        }()

        var numUnits = ""
        var plural = ""
        if let numberOfUnits = numberOfUnits {
            numUnits = "\(numberOfUnits) " // Add space for formatting
            plural = numberOfUnits > 1 ? "s" : ""
        }
        return "\(numUnits)\(capitalizeFirstLetter ? period.capitalized : period)\(plural)"
    }
}
