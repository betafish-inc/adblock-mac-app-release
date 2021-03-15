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

class SafariExtensionHandler: SFSafariExtensionHandler {
    private static var initialized = false
    private let whitelistNotificationName = Notification.Name(rawValue: "\(Constants.SAFARI_MENU_EXTENSION_IDENTIFIER).whitelist")
    private let mergeNotificationName = Notification.Name(rawValue: "\(Constants.SAFARI_MENU_EXTENSION_IDENTIFIER).merge")
    
    override func beginRequest(with context: NSExtensionContext) {
        if !SafariExtensionHandler.initialized {
            SafariExtensionHandler.initialized = true
            FilterListsText.shared.processTextFromFile()
            DistributedNotificationCenter.default().addObserver(self,
                                                                selector: #selector(processFilterListsText),
                                                                name: mergeNotificationName,
                                                                object: nil)
            scheduleDownloadActivity()
        }
        super .beginRequest(with: context)
    }
    
    @objc private func processFilterListsText() {
        FilterListsText.shared.processTextFromFile()
    }
    
    private func scheduleDownloadActivity() {
        let activity = NSBackgroundActivityScheduler(identifier: "com.betafish.adblock-mac.updateHandler")
        activity.repeats = true
        activity.interval = 60 * 60 * 24 // One day
        activity.tolerance = 60 * 60 // One hour
        activity.schedule { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            AssetsManager.shared.downloadDataIfNecessary()
            completion(NSBackgroundActivityScheduler.Result.finished)
        }
    }

    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String: Any]?) {
        guard let info = userInfo else { return }
        if messageName == "add_custom_filter" {
            guard case let url as String = info["url"] else { return }
            
            _ = WhitelistManager.shared.updateCustomFilter(url)
            
            DistributedNotificationCenter.default().post(name: whitelistNotificationName,
                                                         object: Constants.SAFARI_MENU_EXTENSION_IDENTIFIER)
            page.dispatchMessageToScript(withName: "add_custom_filter_response", userInfo: nil)
        } else if messageName == "get_advance_selectors_data" {
            guard case let url as String = info["url"],
                case let parentUrl as String = info["parentUrl"],
                case let domain as String = info["domain"] else {
                return
            }
            
            let advancedSelectorsData = AdvancedHiding.getDataForPage(url: url, parentUrl: parentUrl, domain: domain, page: page)
            
            page.dispatchMessageToScript(withName: "advance_selectors_data_response", userInfo: advancedSelectorsData)
        }
    }
 
    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
        // This is called when Safari's state changed in some way that would require the extension's toolbar item to be validated again.
        PingDataManager.shared.pingDataIfNecessary()
        validationHandler(true, "")
    }
    
    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
    
    override func popoverWillShow(in window: SFSafariWindow) {
        window.getActiveTab { (activeTab) in
            activeTab?.getActivePage { (activePage) in
                activePage?.getPropertiesWithCompletionHandler { (properties) in
                    SafariExtensionViewController.shared.onPopoverVisible(with: properties?.url?.absoluteString)
                }
            }
        }
    }
}
