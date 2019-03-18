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
import ServiceManagement
import SafariServices
import WebKit
import SwiftyStoreKit
import StoreKit

extension Notification.Name {
    static let killLauncher = Notification.Name("com.betafish.adblock-mac.killLauncher")
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let launcherAppId = "com.betafish.adblock-mac.LauncherApp"
    var mainWindow: NSWindow?
    @IBOutlet weak var appMenuBar: AppMenuBar!
    @IBOutlet weak var mainMenuQuit: NSMenuItem!
    @IBOutlet weak var mainMenuAdBlockHelp: NSMenuItem!
    @IBOutlet weak var mainMenuAboutAdBlock: NSMenuItem!
    @IBOutlet weak var mainMenuAbout: NSMenuItem!
    @IBOutlet weak var mainMenuDebug: NSMenuItem!
    @IBOutlet weak var mainMenuPreferences: NSMenuItem!
    @IBOutlet weak var mainMenuServices: NSMenuItem!
    @IBOutlet weak var mainMenuHelp: NSMenu!
    @IBOutlet weak var mainMenuWindow: NSMenu!
    @IBOutlet weak var mainMenuMinimize: NSMenuItem!
    @IBOutlet weak var mainMenuNewWindow: NSMenuItem!
    @IBOutlet weak var mainMenuBringAllToFront: NSMenuItem!
    
    func applicationWillFinishLaunching(_ aNotification: Notification) {
        if (Constants.DEBUG_LOG_ENABLED && SwiftyBeaver.countDestinations() == 0) {
            let console = ConsoleDestination()
            console.minLevel = .verbose
            SwiftyBeaver.addDestination(console)
            if let assetsPath = Constants.AssetsUrls.assetsFolder?.path, FileManager.default.fileExists(atPath: assetsPath) {
                FileManager.default.createDirectoryIfNotExists(Constants.AssetsUrls.logFolder, withIntermediateDirectories: true)
                let file = FileDestination()
                file.logFileURL = Constants.AssetsUrls.logFileURL
                SwiftyBeaver.addDestination(file)
            }
        }
        mainMenuQuit.title = NSLocalizedString("quit.adblock.menu", comment: "")
        mainMenuAdBlockHelp.title = NSLocalizedString("adblock.help.menu", comment: "")
        mainMenuAboutAdBlock.title = NSLocalizedString("about.adblock.menu", comment: "")
        mainMenuAbout.title = NSLocalizedString("about.menu", comment: "")
        mainMenuDebug.title = NSLocalizedString("debug.menu", comment: "")
        mainMenuPreferences.title = NSLocalizedString("preferences.menu", comment: "")
        mainMenuServices.title = NSLocalizedString("services.menu", comment: "")
        mainMenuHelp.title = NSLocalizedString("help.menu", comment: "")
        mainMenuWindow.title = NSLocalizedString("window.menu", comment: "")
        mainMenuMinimize.title = NSLocalizedString("minimize.menu", comment: "")
        mainMenuNewWindow.title = NSLocalizedString("new.window.menu", comment: "")
        mainMenuBringAllToFront.title = NSLocalizedString("bring.all.to.front.menu", comment: "")

        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
        if !isRunning {
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            let mainWC = storyboard.instantiateController(withIdentifier: "MainWC") as! NSWindowController
            mainWC.showWindow(nil)
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.hide(nil)
            NSApp.setActivationPolicy(.accessory)
        }
    }
        
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        AssetsManager.shared.initialize()
        FilterListManager.shared.initialize()
        PingDataManager.shared.start()
        killLauncherIfRunning()
        IAPManager.shared.initialize()

        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
        if !isRunning {
            launchInForeground()
        }
        if (UserPref.purchasedProductId() != nil) {
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
                SwiftyBeaver.debug("  validateReceipt error \(error)")
            }
        }
    }

    private func killLauncherIfRunning() {
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
        if isRunning {
            SwiftyBeaver.debug("killing Launcher")
            DistributedNotificationCenter.default().post(name: .killLauncher,
                                                         object: Bundle.main.bundleIdentifier ?? "")
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if mainWindow != nil && !flag {
            mainWindow?.makeKeyAndOrderFront(self)
        } else if mainWindow == nil && !flag {
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            let mainWC = storyboard.instantiateController(withIdentifier: "MainWC") as! NSWindowController
            mainWC.showWindow(nil)
            launchInForeground()
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
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
        let mainWC = storyboard.instantiateController(withIdentifier: "MainWC") as! NSWindowController
        mainWC.showWindow(nil)
        NSApp.setActivationPolicy(.regular)
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(newWindowClick) {
            return !isWindowOpen()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // if the user shuts down this app, start up the the launcher app using a URL, to restart this app in the correct mode.
        let launcherAppIdentifier = "com.betafish.adblock-mac.LauncherApp"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter {
            $0.bundleIdentifier == launcherAppIdentifier
        }.isEmpty
        if !isRunning && UserPref.isLaunchAppOnUserLogin(), let url = URL(string: "blue:com.betafish.adblock-mac.LauncherApp") {
            let returnVal = NSWorkspace.shared.open(url)
            SwiftyBeaver.debug("started launcher app: \(returnVal.description)")
        }
    }

    // This function handles the odd / hacky behavior needed to launch the app
    // in the foreground, instead of the background.
    // Note that "Application is agent - LSUIElement" is true in the info.plist file requiring this hack,
    // but without it, the user would see the AdBlock icon in the dock for a moment when the app is launched at user login.
    func launchInForeground() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSMenu.setMenuBarVisible(true)
        if let mainMenu = NSApp.mainMenu {
            mainMenu.update()
        }
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
        }
        if (NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.activate(options: []) ?? false) {
            let deadlineTime = DispatchTime.now() + .milliseconds(200)
            DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

@available(OSX 10.13.2, *)
extension SKProduct.PeriodUnit {
    func description(capitalizeFirstLetter: Bool = false, numberOfUnits: Int? = nil) -> String {
        let period:String = {
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

