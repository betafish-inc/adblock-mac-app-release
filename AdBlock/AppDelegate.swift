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

extension Notification.Name {
    static let killLauncher = Notification.Name("com.betafish.adblock-mac.killLauncher")
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var mainWindow: NSWindow?
    @IBOutlet weak var appMenuBar: AppMenuBar!
    @IBOutlet weak var mainMenuQuit: NSMenuItem!
    @IBOutlet weak var mainMenuAdBlockHelp: NSMenuItem!
    @IBOutlet weak var mainMenuAboutAdBlock: NSMenuItem!
    @IBOutlet weak var mainMenuPreferences: NSMenuItem!
    @IBOutlet weak var mainMenuServices: NSMenuItem!
    @IBOutlet weak var mainMenuHelp: NSMenu!
    
    func applicationWillFinishLaunching(_ aNotification: Notification) {
        mainMenuQuit.title = NSLocalizedString("quit.adblock.menu", comment: "")
        mainMenuAdBlockHelp.title = NSLocalizedString("adblock.help.menu", comment: "")
        mainMenuAboutAdBlock.title = NSLocalizedString("about.adblock.menu", comment: "")
        mainMenuPreferences.title = NSLocalizedString("preferences.menu", comment: "")
        mainMenuServices.title = NSLocalizedString("services.menu", comment: "")
        mainMenuHelp.title = NSLocalizedString("help.menu", comment: "")
    }
        
    func applicationDidFinishLaunching(_ aNotification: Notification) {

        if (Constants.DEBUG_LOG_ENABLED) {
            SwiftyBeaver.addDestination(ConsoleDestination())
            let console = ConsoleDestination()
            console.format = "$DHH:mm:ss$d $L: $M"
            console.minLevel = .verbose
        }
        AssetsManager.shared.initialize()
        FilterListManager.shared.initialize()
        killLauncherIfRunning()
    }

    private func killLauncherIfRunning() {
        let launcherAppId = "com.betafish.adblock-mac.LauncherApp"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
        if isRunning {
            DistributedNotificationCenter.default().post(name: .killLauncher,
                                                         object: Bundle.main.bundleIdentifier!)
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            mainWindow?.makeKeyAndOrderFront(self)
        }
        return true
    }
    
    @IBAction func helpMenuClick(_ sender: Any) {
        if !NSWorkspace.shared.openFile(Constants.HELP_PAGE_URL, withApplication: "Safari") {
            guard let url = URL(string: Constants.HELP_PAGE_URL) else { return }
            NSWorkspace.shared.open(url)
        }
    }
}

