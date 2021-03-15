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

class AdvancedHiding: NSObject {
    static func pageIsUnblockable(url: String) -> Bool {
        guard let urlObj = URL(string: url),
            let components = URLComponents(url: urlObj, resolvingAgainstBaseURL: false),
            let scheme = components.scheme else { return true }
        
        return (scheme != "http" && scheme != "https" && scheme != "feed")
    }
    
    // Returns true if anything in whitelist matches the domain.
    //   url: the url of the page
    //   type: one out of ElementTypes, default ElementTypes.document,
    //         to check what the page is whitelisted for: hiding rules or everything
    static func pageIsWhitelisted(url: String, type: Int?, frameDomain: String?) -> Bool {
        if url.isEmpty { return true }
        guard let whitelist = FilterListsText.shared.getWhitelist() else { return false }
        
        let cleanedUrl: String = url.replaceMatches(pattern: "#.*$", replacementString: "") ?? url
        let components = URLComponents(string: cleanedUrl)
        
        return whitelist.matches(url: cleanedUrl,
                                 elementType: type ?? ElementTypes["document"]!,
                                 frameDomain: frameDomain ?? components?.host ?? "",
                                 isThirdParty: false,
                                 matchGeneric: false) != nil
    }
    
    static func getDataForPage(url: String, parentUrl: String, domain: String, page: SFSafariPage) -> [String: Any] {
        let runnable = !PauseResumeBlockinManager.shared.isBlockingPaused() && !pageIsUnblockable(url: url)
        var running = runnable &&
            !WhitelistManager.shared.isEnabled(url) &&
            !pageIsWhitelisted(url: url, type: nil, frameDomain: nil)
        let runningTop = runnable &&
            !WhitelistManager.shared.isEnabled(parentUrl) &&
            !pageIsWhitelisted(url: parentUrl, type: nil, frameDomain: nil)
        var hiding = running && !pageIsWhitelisted(url: url, type: ElementTypes["elemhide"], frameDomain: nil)
        
        if !runningTop && running {
            running = false
            hiding = false
        }
        
        var inline = true
        var advanceSelectors: [SelectorFilter]?
        var snippets: [SnippetFilter]?
        
        if hiding {
            let filterListsTextData = FilterListsText.shared.getFiltersTextData()
            
            // If |matchGeneric| is , don't test request against hiding generic rules
            let matchGeneric = filterListsTextData["whitelist"]??
                .matches(url: parentUrl, elementType: ElementTypes["generichide"]!, frameDomain: parentUrl, isThirdParty: false, matchGeneric: false) != nil
            inline = true
            
            advanceSelectors = filterListsTextData["advancedHiding"]??.advanceFiltersFor(domain: domain, matchGeneric: matchGeneric) as? [SelectorFilter]
            snippets = filterListsTextData["snippets"]??.advanceFiltersFor(domain: domain, matchGeneric: matchGeneric) as? [SnippetFilter]
            
            snippets?.forEach {
                if let script = $0.body {
                    let executableScript = SnippetsHelper.shared.getExecutableCode(script: script)
                    page.dispatchMessageToScript(withName: "injectScript", userInfo: ["evalScript": executableScript, "topOnly": true ])
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
        
        return result
    }
}
