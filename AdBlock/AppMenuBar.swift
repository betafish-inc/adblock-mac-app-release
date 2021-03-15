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

import Foundation
import Cocoa
import ServiceManagement
import SwiftyBeaver

class AppMenuBar: NSObject {
    static let ADS_CLICKED = 1
    static let ALLOW_ADS_CLICKED = 2
    static let ANTI_CIRCUMVENTION_CLICKED = 3
    static var lastFilterListMenuOperation: Int = 0
    
    var statusItem: NSStatusItem?
    
    @IBOutlet weak var menu: NSMenu!
    @IBOutlet weak var adsMenuItem: NSMenuItem!
    @IBOutlet weak var allowAdsMenuItem: NSMenuItem!
    @IBOutlet weak var antiCircumventionMenuItem: NSMenuItem!
    
    override init() {
        super.init()        
    }
    
    func initializeAppMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuBarAppIcon")
        }
        statusItem?.menu = menu
        
        if UserPref.isUpgradeUnlocked {
            antiCircumventionMenuItem.isHidden = false
        } else {
            antiCircumventionMenuItem.isHidden = true
        }
    }
    
    fileprivate func updateFilterListsItemsState() {
        if FilterListManager.shared.isEnabled(filterListId: Constants.ADS_FILTER_LIST_ID) {
            adsMenuItem.state = .on
            allowAdsMenuItem.isEnabled = true
        } else {
            adsMenuItem.state = .off
            allowAdsMenuItem.isEnabled = false
        }
        
        if FilterListManager.shared.isEnabled(filterListId: Constants.ALLOW_ADS_FILTER_LIST_ID) {
            allowAdsMenuItem.state = .on
        } else {
            allowAdsMenuItem.state = .off
        }
        
        if FilterListManager.shared.isEnabled(filterListId: Constants.ANTI_CIRCUMVENTION_LIST_ID) {
            antiCircumventionMenuItem.state = .on
        } else {
            antiCircumventionMenuItem.state = .off
        }
        
        if UserPref.isUpgradeUnlocked {
            antiCircumventionMenuItem.isHidden = false
        } else {
            antiCircumventionMenuItem.isHidden = true
        }
    }
    
    fileprivate func activateApp() {
        NSWorkspace.shared.launchApplication("AdBlock")
    }
    
    @IBAction func adsMenuItemClick(_ sender: NSMenuItem) {
        AppMenuBar.lastFilterListMenuOperation = AppMenuBar.ADS_CLICKED
        if sender.state == .on {
            FilterListManager.shared.disable(filterListId: Constants.ADS_FILTER_LIST_ID)
            FilterListManager.shared.disable(filterListId: Constants.ALLOW_ADS_FILTER_LIST_ID)
        } else {
            FilterListManager.shared.enable(filterListId: Constants.ADS_FILTER_LIST_ID)
        }
        updateFilterListsItemsState()
        FilterListManager.shared.callAssetMerge()
    }
    
    @IBAction func allowAdsMenuItemClick(_ sender: NSMenuItem) {
        AppMenuBar.lastFilterListMenuOperation = AppMenuBar.ALLOW_ADS_CLICKED
        if sender.state == .on {
            FilterListManager.shared.disable(filterListId: Constants.ALLOW_ADS_FILTER_LIST_ID)
        } else {
            FilterListManager.shared.enable(filterListId: Constants.ALLOW_ADS_FILTER_LIST_ID)
        }
        updateFilterListsItemsState()
        FilterListManager.shared.callAssetMerge()
    }
    
    @IBAction func antiCircumventionMenuItemClick(_ sender: NSMenuItem) {
        AppMenuBar.lastFilterListMenuOperation = AppMenuBar.ANTI_CIRCUMVENTION_CLICKED
        if sender.state == .on {
            FilterListManager.shared.disable(filterListId: Constants.ANTI_CIRCUMVENTION_LIST_ID)
        } else {
            FilterListManager.shared.enable(filterListId: Constants.ANTI_CIRCUMVENTION_LIST_ID)
        }
        updateFilterListsItemsState()
        FilterListManager.shared.callAssetMerge()
    }
    
    @IBAction func whitelistMenuItemClick(_ sender: NSMenuItem) {
        activateApp()
        Constants.shouldSelectWhitelist.set(newValue: true)
    }
    
    @IBAction func updateFilterListsMenuItemClick(_ sender: NSMenuItem) {
        activateApp()
        AssetsManager.shared.requestFilterUpdate()
        AlertUtil.displayNotification(title: NSLocalizedString("filter.lists.title", comment: ""),
                                      message: NSLocalizedString("filter.lists.updating", comment: ""))
    }
    
    @IBAction func aboutMenuItemClick(_ sender: Any) {
        activateApp()
        NSApp.orderFrontStandardAboutPanel(self)
    }
}

extension AppMenuBar: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        updateFilterListsItemsState()
    }
}
