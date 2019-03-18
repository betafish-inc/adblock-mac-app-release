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
            FilterListsText.shared.processTextFromFile()
            DistributedNotificationCenter.default().addObserver(self,
                                                                selector: #selector(self.processFilterListsText),
                                                                name: mergeNotificationName,
                                                                object: nil)
            SafariExtensionHandler.initialized = true
        }
        super .beginRequest(with: context)
    }
    
    @objc private func processFilterListsText() {
        FilterListsText.shared.processTextFromFile()
    }
    
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]!) {
        if (messageName == "add_custom_filter") {
            guard case let url as String = userInfo["url"] else {
                return
            }
            if WhitelistManager.shared.exists(url) {
                if WhitelistManager.shared.isEnabled(url) {
                    WhitelistManager.shared.remove(url)
                } else {
                    WhitelistManager.shared.enable(url)
                }
            } else if (WhitelistManager.shared.isValid(url: url)) {
                WhitelistManager.shared.add(url)
            } else {
                return
            }
            
            DistributedNotificationCenter.default().post(name: whitelistNotificationName,
                                                         object: Constants.SAFARI_MENU_EXTENSION_IDENTIFIER)
            page.dispatchMessageToScript(withName: "add_custom_filter_response", userInfo: nil)
        } else if (messageName == "get_advance_selectors_data") {
            guard case let url as String = userInfo["url"] else {
                return
            }
            
            guard case let parentUrl as String = userInfo["parentUrl"] else {
                return
            }
            
            guard case let domain as String = userInfo["domain"] else {
                return
            }
            
            let runnable = !PauseResumeBlockinManager.shared.isBlockingPaused() && !pageIsUnblockable(url: url)
            var running = runnable && !(WhitelistManager.shared.exists(url) && WhitelistManager.shared.isEnabled(url)) && !pageIsWhitelisted(url: url, type: nil, frameDomain: nil)
            let runningTop = runnable && !(WhitelistManager.shared.exists(parentUrl) && WhitelistManager.shared.isEnabled(parentUrl)) && !pageIsWhitelisted(url: parentUrl, type: nil, frameDomain: nil)
            var hiding = running && !pageIsWhitelisted(url: url, type: ElementTypes["elemhide"], frameDomain: nil)
            
            if !runningTop && running {
                running = false;
                hiding = false
            }
            
            var inline = true
            var advanceSelectors: [SelectorFilter]?
            var snippets: [SnippetFilter]?
            
            if hiding {
                let filterListsTextData = FilterListsText.shared.getFiltersTextData()
                
                // If |matchGeneric| is , don't test request against hiding generic rules
                let matchGeneric = filterListsTextData["whitelist"]??.matches(url: parentUrl, elementType: ElementTypes["generichide"]!, frameDomain: parentUrl, isThirdParty: false, matchGeneric: false) != nil
                inline = true
                
                advanceSelectors = filterListsTextData["advancedHiding"]??.advanceFiltersFor(domain: domain, matchGeneric: matchGeneric) as? [SelectorFilter]
                snippets = filterListsTextData["snippets"]??.advanceFiltersFor(domain: domain, matchGeneric: matchGeneric) as? [SnippetFilter]
                
                if let snippetArray = snippets {
                    for filter in snippetArray {
                        if let script = filter.body {
                            let executableScript = SnippetsHelper.shared.getExecutableCode(script: script)
                            page.dispatchMessageToScript(withName: "injectScript", userInfo: ["evalScript": executableScript, "topOnly": true ])
                        }
                    }
                }
            }
            
            // Convert from Filter objects to JavaScript compatible data type (for sending to the content script)
            var filtersResult: [[String: String]] = []
            if let selectors = advanceSelectors {
                var filterSub: [String: String] = [:]
                for filter in selectors {
                    filterSub["selector"] = filter.selector ?? ""
                    filterSub["text"] = filter.text ?? ""
                    filtersResult.append(filterSub)
                }
            }
            
            var result: [String: Any] = [:]
            result["runnable"] = runnable
            result["running"] = running
            result["runningTop"] = runningTop
            result["hiding"] = hiding
            result["inline"] = inline
            result["advanceSelectors"] = filtersResult
            
            page.dispatchMessageToScript(withName: "advance_selectors_data_response", userInfo: result)
        }
    }
    
    private func pageIsUnblockable(url: String) -> Bool {
        if let urlObj = URL(string: url) {
            let components = URLComponents(url: urlObj, resolvingAgainstBaseURL: false)
            if let scheme = components?.scheme {
                return (scheme != "http" && scheme != "https" && scheme != "feed")
            }
        }
        return true
    }
    
    // Returns true if anything in whitelist matches the_domain.
    //   url: the url of the page
    //   type: one out of ElementTypes, default ElementTypes.document,
    //         to check what the page is whitelisted for: hiding rules or everything
    private func pageIsWhitelisted(url: String, type: Int?, frameDomain: String?) -> Bool {
        if url == "" {
            return true
        }
        
        var cleanedUrl: String
        do {
            cleanedUrl = try replaceMatches(pattern: "#.*$", inString: url, replacementString: "") ?? url
        } catch {
            cleanedUrl = url
        }
        
        if FilterListsText.shared.getWhitelist() == nil {
            return false
        }
        
        let components = URLComponents(string: cleanedUrl)
        
        return FilterListsText.shared.getWhitelist()?.matches(url: cleanedUrl, elementType: type ?? ElementTypes["document"]!, frameDomain: frameDomain ?? components?.host ?? "", isThirdParty: false, matchGeneric: false) != nil
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
            activeTab?.getActivePage(completionHandler: { (activePage) in
                activePage?.getPropertiesWithCompletionHandler( { (properties) in
                    SafariExtensionViewController.shared.onPopoverVisible(with: properties?.url?.absoluteString)
                })
            })
        }
    }
}
