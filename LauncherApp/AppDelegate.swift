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

extension Notification.Name {
    static let killLauncher = Notification.Name("com.betafish.adblock-mac.killLauncher")
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if (Constants.DEBUG_LOG_ENABLED) {
            let console = ConsoleDestination()
            console.format = "$DHH:mm:ss$d $L: $M"
            console.minLevel = .verbose
            SwiftyBeaver.addDestination(console)
            if let assetPath = Constants.AssetsUrls.assetsFolder?.path, FileManager.default.fileExists(atPath: assetPath) {
                FileManager.default.createDirectoryIfNotExists(Constants.AssetsUrls.logFolder, withIntermediateDirectories: true)
                let file = FileDestination()
                file.logFileURL = Constants.AssetsUrls.logFileURL
                SwiftyBeaver.addDestination(file)
            }
        }
        let mainAppIdentifier = "com.betafish.adblock-mac"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == mainAppIdentifier }.isEmpty

        if !isRunning {
            DistributedNotificationCenter.default().addObserver(self,
                                                                selector: #selector(self.terminate),
                                                                name: .killLauncher,
                                                                object: mainAppIdentifier)

            let path = Bundle.main.bundlePath as NSString
            var components = path.pathComponents
            components.removeLast()
            components.removeLast()
            components.removeLast()
            components.append("MacOS")
            components.append("AdBlock") //main app name
            let newPath = NSString.path(withComponents: components)
            let returnVal = NSWorkspace.shared.launchApplication(newPath)
            SwiftyBeaver.debug("started main app hidden return value: \(returnVal.description)")
        } else {
            self.terminate()
        }
    }
    
    @objc func terminate() {
        SwiftyBeaver.debug("launcher app terminate")
        NSApp.terminate(nil)
    }
}
