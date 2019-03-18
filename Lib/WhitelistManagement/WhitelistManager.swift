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
import Punycode_Cocoa
import SafariServices
import SwiftyBeaver

enum WhitelistManagerStatus {
    case idle
    
    case whitelistUpdateStarted
    case whitelistUpdateCompleted
    case whitelistUpdateError    
}

class WhitelistManager: NSObject {
    static let shared: WhitelistManager = WhitelistManager()
    
    var status: Observable<WhitelistManagerStatus> = Observable(.idle)
    var whitelistQueue = DispatchQueue(label: "whitelistQueue")
    
    func isValid(url: String) -> Bool {
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            if let match = detector.firstMatch(in: url, options: [], range: NSRange(location: 0, length: url.endIndex.encodedOffset)) {
                // it is a URL, if the match covers the whole string
                return match.range.length == url.endIndex.encodedOffset
            } else {
                return false
            }
        } catch {
            return false
        }
    }
    
    func removeUrlComponentsAfterHost(url: String) -> String {
        var host = ""
        var firstSlashRange: Range<String.Index>?
        if let protocolRange = url.range(of: "://") {
            let searchRange = Range<String.Index>(uncheckedBounds: (lower: protocolRange.upperBound, upper: url.endIndex))
            firstSlashRange = url.range(of: "/", options: .literal, range: searchRange, locale: Locale.current)
        } else {
            firstSlashRange = url.range(of: "/", options: .literal, range: nil, locale: Locale.current)
        }
        host = String(url[..<(firstSlashRange?.lowerBound ?? url.endIndex)])
        return host
    }

    // add 
    func add(_ url: String) {
        self.whitelistQueue.async {
            self.status.set(newValue: .whitelistUpdateStarted)
            let normalizedUrl = self.normalizeUrl(url)
            let rule = self.prepareRule(normalizedUrl)
            let whitelist: [String : Any] = ["originalEntry": normalizedUrl, "active": self.canEnable(), "rule": rule]
            
            var whitelists: [[String:Any]]? = self.getAll() ?? []
            whitelists?.append(whitelist)
            self.save(whitelists)
            self.status.set(newValue: .whitelistUpdateCompleted)
            self.status.set(newValue: .idle)
            self.callAssetMerge()
        }
    }
    
    func remove(_ url: String) {
        self.whitelistQueue.async {
            self.status.set(newValue: .whitelistUpdateStarted)
            let normalizedUrl = self.normalizeUrl(url)
            let domainAndParent = self.domainAndParents(normalizedUrl)
            let whitelists: [[String:Any]]? = self.getAll() ?? []
            let newWhitelists = whitelists?.filter({ (whitelist) -> Bool in
                guard let domain = whitelist["originalEntry"] as? String else { return false }
                var exactMatch = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != normalizedUrl.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                // if this function is invoded from the Safari toolbar icon,
                // then a full URL, including the http/https protocol should be included,
                // but the text in the whitelist rules may not include the protocol, so test for it
                if (exactMatch && !domain.hasPrefix("http") && normalizedUrl.hasPrefix("http")) {
                    var protocolPrefix = "http://"
                    if normalizedUrl.hasPrefix("https") {
                        protocolPrefix = "https://"
                    }
                    exactMatch = protocolPrefix + domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != normalizedUrl.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                }
                // if the normalized URL doesn't match the domain, then check if there's parent / sub-domain match
                // the return from 'first' will be nil if there isn't a match found
                let domainAndParentMatch = ((domainAndParent?.first(where: {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                )) == nil)

                // both values must be true to keep the element.
                return exactMatch && domainAndParentMatch
            })
            self.save(newWhitelists)
            self.status.set(newValue: .whitelistUpdateCompleted)
            self.status.set(newValue: .idle)
            self.callAssetMerge()
        }
    }
    
    func enable(_ url: String) {
        self.whitelistQueue.async {
            self.status.set(newValue: .whitelistUpdateStarted)
            guard var whitelists = self.getAll() else {
                self.status.set(newValue: .idle)
                return
            }
            
            guard let (whitelist, index) = self.findEntryAndIndex(of: url, in: whitelists) else {
                self.status.set(newValue: .idle)
                return
            }
            var currentWhitelist = whitelist
            currentWhitelist["active"] = true
            whitelists[index] = currentWhitelist
            
            self.save(whitelists)
            self.status.set(newValue: .whitelistUpdateCompleted)
            self.status.set(newValue: .idle)
            self.callAssetMerge()
        }
    }
    
    func disable(_ url: String) {
        self.whitelistQueue.async {
            self.status.set(newValue: .whitelistUpdateStarted)
            guard var whitelists = self.getAll() else {
                self.status.set(newValue: .idle)
                return
            }
            
            guard let (whitelist, index) = self.findEntryAndIndex(of: url, in: whitelists) else {
                self.status.set(newValue: .idle)
                return
            }
            var currentWhitelist = whitelist
            currentWhitelist["active"] = false
            whitelists[index] = currentWhitelist
            
            self.save(whitelists)
            self.status.set(newValue: .whitelistUpdateCompleted)
            self.status.set(newValue: .idle)
            self.callAssetMerge()
        }
    }
    
    func isEnabled(_ url: String) -> Bool {
        guard let whitelists = getAll() else { return false }
        guard let (whitelist, _) = findEntryAndIndex(of: url, in: whitelists) else {
            // since isEnabled is only called from the Safari toolbar icon
            // the URL parameter should always include a protocol, but
            // the whitelist rules may not include the protocol,
            // so, see if we get a match without it
            if (url.hasPrefix("https://")) {
                let newURL = String(url.dropFirst(8))
                guard let (_, _) = findEntryAndIndex(of: newURL, in: whitelists) else {
                    return false
                }
                return true
            } else if (url.hasPrefix("http://")) {
                let newURL = String(url.dropFirst(7))
                guard let (_, _) = findEntryAndIndex(of: newURL, in: whitelists) else {
                    return false
                }
                return true
            }
            return false
        }
        return whitelist["active"] as? Bool ?? false == true
    }
    
    func exists(_ url: String, exactMatch: Bool = false) -> Bool {
        guard let whitelists = getAll() else { return false }
        guard let (_, _) = findEntryAndIndex(of: url, in: whitelists, exactMatch: exactMatch) else {
            if (exactMatch) {
                return false
            }
            if (url.hasPrefix("https://")) {
                let newURL = String(url.dropFirst(8))
                guard let (_, _) = findEntryAndIndex(of: newURL, in: whitelists, exactMatch: exactMatch) else {
                    return false
                }
                return true
            } else if (url.hasPrefix("http://")) {
                let newURL = String(url.dropFirst(7))
                guard let (_, _) = findEntryAndIndex(of: newURL, in: whitelists, exactMatch: exactMatch) else {
                    return false
                }
                return true
            } else {
                var newURL = "http://" + url
                guard let (_, _) = findEntryAndIndex(of: newURL, in: whitelists, exactMatch: exactMatch) else {
                    newURL = "https://" + url
                    guard let (_, _) = findEntryAndIndex(of: newURL, in: whitelists, exactMatch: exactMatch) else {
                        return false
                    }
                    return true
                }
                return true
            }
        }
        return true
    }
    
    func getAllItems() -> [Item]? {
        guard let whitelists = getAll() else { return [] }
        var whitelistItems: [Item]? = []
        for whitelist in whitelists {
            let id = whitelist["originalEntry"] as? String
            let name = whitelist["originalEntry"] as? String
            let active = whitelist["active"] as? Bool
            whitelistItems?.append(Item(id: id, name: name, active: active, desc: ""))
        }
        if whitelistItems?.isEmpty ?? true {
            whitelistItems?.append(Item(id: Item.EMPTY_WHITELIST_ITEM_ID, name: "", active: true))
        }
        return whitelistItems?.reversed()
    }
    
    func getActiveWhitelistRules() -> [[String:Any]]? {
        guard let whitelists = getAll() else { return [] }
        let activeWhitelists = whitelists.filter { (whitelist) -> Bool in
            return whitelist["active"] as? Bool ?? false
            }.compactMap { (activeWhitelist) -> [String: Any]? in
                return activeWhitelist["rule"] as? [String: Any]
        }
        return activeWhitelists
    }
    
    private func callAssetMerge() {
        AssetsManager.shared.requestMerge()
    }
    
    func canEnable() -> Bool {
        guard let mergedRules: [[String:Any]]? = FileManager.default.readJsonFile(at: Constants.AssetsUrls.mergedRulesUrl) else { return true }
        let activeRulesCount = mergedRules?.count ?? 0
        return (activeRulesCount + 1) <= Constants.CONTENT_BLOCKING_RULES_LIMIT
    }
    
    private func getAll() -> [[String:Any]]? {
        let whitelists: [[String:Any]]? = FileManager.default.readJsonFile(at: Constants.AssetsUrls.whitelistUrl)
        return convertRules(whitelists)
    }
    
    private func prepareRule(_ url: String) -> [String: Any] {
        let rule = WhitelistRulesMaker.shared.makeRule(for: url)
        return rule
    }
    
    private func save(_ rules: [[String:Any]]?) {
        FileManager.default.writeJsonFile(at: Constants.AssetsUrls.whitelistUrl, with: rules)
    }
    
    private func removeProtocol(from url: String) -> String {
        let dividerRange = url.range(of: "://")
        guard let divide = dividerRange?.upperBound else { return url }
        let path = String(url[divide...])
        return path
    }

    // search for a url
    private func findEntryAndIndex(of url: String, in whitelists: [[String:Any]], exactMatch: Bool = false) -> ([String:Any], Int)? {
        let normalizedUrl = normalizeUrl(url)
        SwiftyBeaver.debug("normalizedUrl \(normalizedUrl)")
        let domainAndParent = domainAndParents(normalizedUrl)
        guard let currentUrlWhitelist = whitelists.filter({ (whitelist) -> Bool in
            guard let domain = whitelist["originalEntry"] as? String else { return false }
            var returnValue = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedUrl.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            // if the normalized URL doesn't match the domain, then check if there's parent / sub-domain match
            if (!exactMatch && !returnValue) {
                returnValue = ((domainAndParent?.first(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })) != nil)
            }
            return returnValue
        }).first else {
            return nil
        }
        guard let index = whitelists.index(where: { (whitelist) -> Bool in
            guard let domain = whitelist["originalEntry"] as? String else { return false }
            var returnValue = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedUrl.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            // if the normalized URL doesn't match the domain, then check if there's parent / sub-domain match
            if (!exactMatch && !returnValue) {
                returnValue = ((domainAndParent?.first(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })) != nil)
            }
            return returnValue
        }) else {
            return nil
        }
        return (currentUrlWhitelist, index)
    }
    
    func normalizeUrl(_ url: String) -> String {
        var url = url
        if url.count == 0 {
            return url
        }
        if (!SFSafariServicesAvailable(SFSafariServicesVersion.version11_0)) {
            let host = removeUrlComponentsAfterHost(url: url)
            var normalizedUrl = removeProtocol(from: host)
            if normalizedUrl.starts(with: "www.") {
                normalizedUrl = normalizedUrl.replacingOccurrences(of: "www.", with: "")
            }

            normalizedUrl = (normalizedUrl as NSString).decodedURL ?? normalizedUrl
            return normalizedUrl.lowercased()
        }
        if url.last! == "/" {
            url = String(url.dropLast())
        }
        return url.lowercased()
    }

    private func convertRules(_ rules: [[String:Any]]?) -> [[String:Any]]? {
        if (!SFSafariServicesAvailable(SFSafariServicesVersion.version11_0)) {
            return rules
        }
        if UserPref.isConvertedRulesToIfTop() {
            return rules
        }
        guard let currentRules = rules else {
            return rules
        }
        var convertedRules: [[String:Any]]? = []
        for whitelist in currentRules {
            guard let domain = whitelist["domain"] as? String else {
                continue
            }
            let rule = WhitelistRulesMaker.shared.makeRule(for: domain)
            guard let active = whitelist["active"] as? Bool else {
                continue
            }
            let whitelistEntry: [String : Any] = ["originalEntry": domain, "active": active, "rule": rule]
            convertedRules?.append(whitelistEntry)
        }
        self.save(convertedRules)
        UserPref.setConvertedRulesToIfTop(true)
        return convertedRules
    }


    // Return an array whose entries are |domain| and all of its parent domains, up
    // to and including the TLD.
    func domainAndParents(_ url: String) -> [String]? {
        var domain = url
        if (url.hasPrefix("https://") || url.hasPrefix("http://")), let theURL = URL(string: url), let domainHost = theURL.host {
            domain = domainHost
        }
        var result: [String]? = []
        var parts = domain.components(separatedBy: ".")
        var nextDomain = parts[parts.count - 1]
        for (index, _) in parts.enumerated().reversed()  {
            result?.append(nextDomain)
            if (index > 0) {
                nextDomain = parts[index - 1] + "." + nextDomain
            }
        }
        return result
    }
}
