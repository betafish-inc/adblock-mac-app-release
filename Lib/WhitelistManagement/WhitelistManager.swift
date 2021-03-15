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

extension String {
    func trimAndLower() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    func isValidUrl() -> Bool {
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            if let match = detector.firstMatch(in: self, options: [], range: NSRange(location: 0, length: self.endIndex.utf16Offset(in: self))) {
                // it is a URL, if the match covers the whole string
                return match.range.length == self.endIndex.utf16Offset(in: self)
            } else {
                return false
            }
        } catch {
            return false
        }
    }
    
    func getHostname() -> String {
        return URL(string: self)?.host ?? ""
    }
}

struct Whitelist {
    var id: String
    var name: String
    var active: Bool
}

class WhitelistManager: NSObject {
    static let shared: WhitelistManager = WhitelistManager()
    
    var status: Observable<WhitelistManagerStatus> = Observable(.idle)
    var whitelistQueue = DispatchQueue(label: "whitelistQueue")
    
    // add 
    func add(_ url: String) {
        whitelistQueue.async {[weak self] in
            guard let strongSelf = self else { return }
            strongSelf.status.set(newValue: .whitelistUpdateStarted)
            let normalizedUrl = strongSelf.normalizeUrl(url)
            let rule = strongSelf.prepareRule(normalizedUrl)
            let whitelist: [String: Any] = ["originalEntry": normalizedUrl, "active": strongSelf.canEnable(), "rule": rule]
            
            var whitelists: [[String: Any]]? = strongSelf.getAll() ?? []
            whitelists?.append(whitelist)
            strongSelf.saveAndMerge(whitelists)
        }
    }
    
    func remove(_ url: String) {
        whitelistQueue.async {[weak self] in
            guard let strongSelf = self else { return }
            strongSelf.status.set(newValue: .whitelistUpdateStarted)
            let normalizedUrl = strongSelf.normalizeUrl(url)
            let domainAndParent = strongSelf.domainAndParents(normalizedUrl)
            let whitelists: [[String: Any]]? = strongSelf.getAll() ?? []
            // filter out any matching rules
            let newWhitelists = whitelists?.filter { (whitelist) -> Bool in
                guard let domain = (whitelist["originalEntry"] as? String)?.trimAndLower() else { return false }
                var exactMatch = domain != normalizedUrl
                // if this function is invoked from the Safari toolbar icon,
                // then a full URL, including the http/https protocol should be included,
                // but the text in the whitelist rules may not include the protocol, so test for it
                if exactMatch && !domain.hasPrefix("http") && normalizedUrl.hasPrefix("http") {
                    var protocolPrefix = "http://"
                    if normalizedUrl.hasPrefix("https") {
                        protocolPrefix = "https://"
                    }
                    exactMatch = protocolPrefix + domain != normalizedUrl
                }
                // if the normalized URL doesn't match the domain, then check if there's parent / sub-domain match
                // the return from 'first' will be nil if there isn't a match found
                let domainAndParentMatch = ((domainAndParent.first { $0.trimAndLower() == domain }) == nil)

                // both values must be true to keep the element.
                return exactMatch && domainAndParentMatch
            }
            strongSelf.saveAndMerge(newWhitelists)
        }
    }
    
    func enable(_ url: String) {
        updateRule(url, updatedStatus: true)
    }
    
    func disable(_ url: String) {
        updateRule(url, updatedStatus: false)
    }
    
    private func updateRule(_ url: String, updatedStatus: Bool) {
        whitelistQueue.async {[weak self] in
            guard let strongSelf = self else { return }
            strongSelf.status.set(newValue: .whitelistUpdateStarted)
            guard var whitelists = strongSelf.getAll() else {
                strongSelf.status.set(newValue: .idle)
                return
            }
            
            guard let (whitelist, index) = strongSelf.findEntryAndIndex(of: url, in: whitelists) else {
                strongSelf.status.set(newValue: .idle)
                return
            }
            var currentWhitelist = whitelist
            currentWhitelist["active"] = updatedStatus
            whitelists[index] = currentWhitelist
            
            strongSelf.saveAndMerge(whitelists)
        }
    }
    
    func isEnabled(_ url: String, exactMatch: Bool = false) -> Bool {
        if let (whitelist, _) = getEntry(url, exactMatch: exactMatch) {
            return whitelist["active"] as? Bool ?? false
        }
        return false
    }
    
    func exists(_ url: String, exactMatch: Bool = false) -> Bool {
        if getEntry(url, exactMatch: exactMatch) != nil {
            return true
        }
        return false
    }
    
    private func getEntry(_ url: String, exactMatch: Bool = false) -> ([String: Any], Int)? {
        guard let whitelists = getAll() else { return nil }
        if let match = findEntryAndIndex(of: url, in: whitelists, exactMatch: exactMatch) {
            return match
        } else {
            if exactMatch {
                return nil
            }
            if url.hasPrefix("https://") {
                let newURL = String(url.dropFirst(8))
                return findEntryAndIndex(of: newURL, in: whitelists, exactMatch: exactMatch)
            } else if url.hasPrefix("http://") {
                let newURL = String(url.dropFirst(7))
                return findEntryAndIndex(of: newURL, in: whitelists, exactMatch: exactMatch)
            } else {
                var newURL = "http://\(url)"
                if let match = findEntryAndIndex(of: newURL, in: whitelists, exactMatch: exactMatch) {
                    return match
                } else {
                    newURL = "https://\(url)"
                    return findEntryAndIndex(of: newURL, in: whitelists, exactMatch: exactMatch)
                }
            }
        }
    }
    
    func getAllItems() -> [Whitelist]? {
        guard let whitelists = getAll() else { return [] }
        var whitelistItems: [Whitelist]? = []
        for whitelist in whitelists {
            let id = whitelist["originalEntry"] as? String ?? ""
            let name = whitelist["originalEntry"] as? String ?? ""
            let active = whitelist["active"] as? Bool ?? false
            whitelistItems?.append(Whitelist(id: id, name: name, active: active))
        }
        if whitelistItems?.isEmpty ?? true {
            whitelistItems?.append(Whitelist(id: Constants.EMPTY_WHITELIST_ITEM_ID, name: "", active: true))
        }
        return whitelistItems?.reversed()
    }
    
    func getActiveWhitelistRules() -> [[String: Any]]? {
        guard let whitelists = getAll() else { return [] }
        let activeWhitelists = whitelists.filter { (whitelist) -> Bool in
            return whitelist["active"] as? Bool ?? false
        }.compactMap { (activeWhitelist) -> [String: Any]? in
            return activeWhitelist["rule"] as? [String: Any]
        }
        return activeWhitelists
    }
    
    func canEnable() -> Bool {
        guard let mergedRules: [[String: Any]]? = FileManager.default.readJsonFile(at: .mergedRulesFile) else { return true }
        let activeRulesCount = mergedRules?.count ?? 0
        return (activeRulesCount + 1) <= Constants.CONTENT_BLOCKING_RULES_LIMIT
    }
    
    private func getAll() -> [[String: Any]]? {
        let whitelists: [[String: Any]]? = FileManager.default.readJsonFile(at: .whitelistFile)
        return convertRules(whitelists)
    }
    
    private func prepareRule(_ url: String) -> [String: Any] {
        return WhitelistRulesMaker.shared.makeRule(for: url)
    }
    
    private func save(_ rules: [[String: Any]]?) {
        FileManager.default.writeJsonFile(at: .whitelistFile, with: rules)
    }
    
    private func saveAndMerge(_ rules: [[String: Any]]?) {
        self.save(rules)
        self.status.set(newValue: .whitelistUpdateCompleted)
        self.status.set(newValue: .idle)
        AssetsManager.shared.requestMerge()
    }
    
    // search for a url
    private func findEntryAndIndex(of url: String, in whitelists: [[String: Any]], exactMatch: Bool = false) -> ([String: Any], Int)? {
        if url.isEmpty { return nil }
        let normalizedUrl = normalizeUrl(url)
        SwiftyBeaver.debug("normalizedUrl \(normalizedUrl)")
        let domainAndParent = domainAndParents(normalizedUrl)
        guard let index = whitelists.firstIndex(where: { (whitelist) -> Bool in
            guard let domain = (whitelist["originalEntry"] as? String)?.trimAndLower() else { return false }
            var returnValue = domain == normalizedUrl
            // if the normalized URL doesn't match the domain, then check if there's a parent / sub-domain match
            if !exactMatch && !returnValue {
                returnValue = ((domainAndParent.first(where: { $0.trimAndLower() == domain })) != nil)
            }
            return returnValue
        }) else {
            return nil
        }
        return (whitelists[index], index)
    }
    
    func normalizeUrl(_ urlString: String) -> String {
        var url = urlString.trimAndLower()
        
        if url.isEmpty { return url }
        
        if !SFSafariServicesAvailable(SFSafariServicesVersion.version11_0) {
            var normalizedUrl = url.getHostname()
            if normalizedUrl.starts(with: "www.") {
                normalizedUrl = normalizedUrl.replacingOccurrences(of: "www.", with: "")
            }

            normalizedUrl = (normalizedUrl as NSString).decodedURL ?? normalizedUrl
            return normalizedUrl
        }
        if url.last == "/" {
            url = String(url.dropLast())
        }
        return url
    }

    private func convertRules(_ rules: [[String: Any]]?) -> [[String: Any]]? {
        if !SFSafariServicesAvailable(SFSafariServicesVersion.version11_0) ||
            UserPref.isConvertedRulesToIfTop {
            return rules
        }
        
        guard let currentRules = rules else { return rules }
        
        var convertedRules: [[String: Any]]? = []
        for whitelist in currentRules {
            guard let domain = whitelist["domain"] as? String,
                let active = whitelist["active"] as? Bool else {
                continue
            }
            
            let rule = WhitelistRulesMaker.shared.makeRule(for: domain)
            let whitelistEntry: [String: Any] = ["originalEntry": domain, "active": active, "rule": rule]
            convertedRules?.append(whitelistEntry)
        }
        save(convertedRules)
        UserPref.setConvertedRulesToIfTop(true)
        return convertedRules
    }

    // Return an array whose entries are |domain| and all of its parent domains, up
    // to and including the TLD.
    func domainAndParents(_ url: String) -> [String] {
        var domain = url
        if let theURL = URL(string: url), let domainHost = theURL.host {
            domain = domainHost
        }
        var result: [String] = []
        _ = domain.split(separator: ".").reversed().reduce("") { (last, part) in
            var next: String
            if !last.isEmpty {
                next = "\(String(part)).\(last)"
            } else {
                next = "\(String(part))"
            }
            result.append(next)
            return next
        }
        
        return result
    }
    
    func updateCustomFilter(_ url: String) -> Bool {
        if isEnabled(url) {
            remove(url)
        } else if exists(url) {
            enable(url)
        } else if url.isValidUrl() {
            add(url)
        } else {
            return false
        }
        return true
    }
}
