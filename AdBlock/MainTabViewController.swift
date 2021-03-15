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

private enum TabItem: Int {
    case introTab = 0
    case readyTab = 1
    case appTab = 2
}

class MainTabViewController: NSTabViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let readyTVItem = tabViewItems[1] as NSTabViewItem
        if let readyVC = readyTVItem.viewController as? ReadyViewController {
            readyVC.delegate = self
        }
        
        if !UserPref.isIntroScreenShown {
            checkExtensionIsEnabled()
        } else {
            selectedTabViewItemIndex = TabItem.appTab.rawValue
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        if UserPref.isIntroScreenShown {
            self.view.window?.titleVisibility = .visible
        } else {
            self.view.window?.titleVisibility = .hidden
        }
    }
    
    private func checkExtensionIsEnabled() {
        var safariContentBlockerEnabled = false
        var safariMenuEnabled = false
        let group = DispatchGroup()
        
        group.enter()
        DispatchQueue.main.async(group: group) {
            SFContentBlockerManager.getStateOfContentBlocker(withIdentifier: Constants.SAFARI_CONTENT_BLOCKER_EXT_IDENTIFIER) { (state, error) in
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
        
        group.notify(queue: .main) {[weak self] in
            guard let strongSelf = self else { return }
            
            if !UserPref.isIntroScreenShown {
                if safariContentBlockerEnabled && safariMenuEnabled {
                    strongSelf.selectedTabViewItemIndex = TabItem.readyTab.rawValue
                } else {
                    strongSelf.selectedTabViewItemIndex = TabItem.introTab.rawValue
                }
            
                strongSelf.checkExtensionIsEnabled()
            } else {
                strongSelf.selectedTabViewItemIndex = TabItem.appTab.rawValue
            }
        }
    }
}

extension MainTabViewController: ReadyVCDelegate {
    func startApp() {
        UserPref.setIntroScreenShown(true)
        selectedTabViewItemIndex = TabItem.appTab.rawValue
        self.view.window?.titleVisibility = .visible
    }
}
