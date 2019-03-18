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

class MainWindowController: NSWindowController {

    override func windowDidLoad() {
        super.windowDidLoad()
        let appDelegate = NSApplication.shared.delegate as? AppDelegate
        appDelegate?.mainWindow = self.window

        if UserPref.isIntroScreenShown() {
            self.contentViewController = NSStoryboard.mainVC()
            self.window?.titleVisibility = .visible
        } else {
            let introVC = NSStoryboard.introVC()
            introVC.delegate = self
            self.contentViewController = introVC
            self.window?.titleVisibility = .hidden
        }
    }

    override func windowWillLoad() {
        super.windowWillLoad()
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
    }

}

extension MainWindowController: IntroVCDelegate {
    func startApp() {
        UserPref.setIntroScreenShown(true)
        self.contentViewController = nil
        self.contentViewController = NSStoryboard.mainVC()
        self.window?.titleVisibility = .visible
    }
}
