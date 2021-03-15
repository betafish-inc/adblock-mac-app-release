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

struct UserPref {
    static var isFileAccessBlocked: Bool {
        return userDefaultsGroup?.bool(forKey: "FILE_ACCESS_BLOCKED") ?? false
    }
    
    static var isDonationPageShown: Bool {
        return readPreferenceValue(of: "DONATION_PAGE_OPENED") ?? false
    }

    static var isIntroScreenShown: Bool {
        return readPreferenceValue(of: "IS_INTRO_SCREEN_SHOWN") ?? false
    }
    
    static var filterListsUpdatedDate: Date {
        let seconds: Int = readPreferenceValue(of: "LAST_UPDATED_DATE") ?? Int(Date().timeIntervalSince1970.rounded())
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }
    
    static var isBundledAssetsDefaultStateUpdated: Bool {
        return readPreferenceValue(of: "BUNDLED_ASSETS_DEFAULT_STATE_UPDATED") ?? false
    }
    
    static var lastNotifiedDateForDisabledExtension: Date? {
        guard let seconds: Int = readPreferenceValue(of: "LAST_NOTIFIED_DATE_FOR_DISABLED_EXTENSION") else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }
    
    static var isBlockingPaused: Bool {
        return readPreferenceValue(of: "PAUSE_BLOCKING") ?? false
    }
    
    static var operatingSystem: String {
        return readPreferenceValue(of: "OS") ?? "Unknown"
    }
    
    static var operatingSystemVersion: String {
        return readPreferenceValue(of: "OS_VERSION") ?? "Unknown"
    }
    
    static var safariVersion: String {
        return readPreferenceValue(of: "SAFARI_VERSION") ?? "Unknown"
    }
    
    static var safariLanguage: String {
        return readPreferenceValue(of: "SAFARI_LANG") ?? "Unknown"
    }
    
    static var userId: String? {
        return readPreferenceValue(of: "USER_ID")
    }
    
    static var totalPings: Int {
        return readPreferenceValue(of: "TOTAL_PINGS") ?? 0
    }
    
    static var lastPingDate: Date? {
        guard let seconds: Int = readPreferenceValue(of: "LAST_PING_DATE") else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }
    
    static var isConvertedRulesToIfTop: Bool {
        return readPreferenceValue(of: "CONVERTED_RULES_TO_IF_TOP") ?? false
    }
    
    static var purchasedProductId: String? {
        return readPreferenceValue(of: "PURCHASED_PRODUCT_ID")
    }
    
    static var isUpgradeUnlocked: Bool {
        return readPreferenceValue(of: "WHITELIST_WIZARD_UNLOCKED") ?? false
    }
    
    private init() {}
    
    static let userDefaultsGroup = UserDefaults(suiteName: Constants.GROUP_IDENTIFIER)
    
    private static func writePreferenceValue(withOperation operation: (_ pref: inout [String: Any]?) -> Void) -> Bool {
        var pref: [String: Any]? = FileManager.default.readJsonFile(at: .userPreferenceFile) ?? [:]
        operation(&pref)
        return FileManager.default.writeJsonFile(at: .userPreferenceFile, with: pref)
    }
    
    private static func readPreferenceValue<T>(of key: String) -> T? {
        guard let pref: [String: Any]? = FileManager.default.readJsonFile(at: .userPreferenceFile) else {
            let initialPreference: [String: Any]? = ["__dummy_pref__": "__AdBlock__"]
            _ = FileManager.default.writeJsonFile(at: .userPreferenceFile, with: initialPreference)
            return nil
        }
        
        return pref?[key] as? T
    }
    
    static func setFileAccessBlocked(_ blocked: Bool) {
        userDefaultsGroup?.set(blocked, forKey: "FILE_ACCESS_BLOCKED")
    }
    
    static func setDonationPageShown(_ opened: Bool) {
        _ = writePreferenceValue { (pref) in
            pref?["DONATION_PAGE_OPENED"] = opened
        }
    }
    
    static func setIntroScreenShown(_ introShown: Bool) {
        _ = writePreferenceValue { (pref) in
            pref?["IS_INTRO_SCREEN_SHOWN"] = introShown
        }
    }
    
    static func setFilterListsUpdatedDate(_ date: Date) {
        _ = writePreferenceValue { (pref) in
            pref?["LAST_UPDATED_DATE"] = Int(date.timeIntervalSince1970.rounded())
        }
    }

    static func setFilterListModifiedDate(identifier: String, date: Date) {
        _ = writePreferenceValue { (pref) in
            pref?["\(identifier)_updated"] = Int(date.timeIntervalSince1970.rounded())
        }
    }

    static func filterListModifiedDate(identifier: String) -> Date {
        let seconds: Int = readPreferenceValue(of: "\(identifier)_updated") ?? 0
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }
    
    static func setBundledAssetsDefaultStateUpdated(_ stateUpdated: Bool) {
        _ = writePreferenceValue { (pref) in
            pref?["BUNDLED_ASSETS_DEFAULT_STATE_UPDATED"] = stateUpdated
        }
    }
    
    static func setLastNotifiedDateForDisabledExtension(_ date: Date) {
        _ = writePreferenceValue { (pref) in
            pref?["LAST_NOTIFIED_DATE_FOR_DISABLED_EXTENSION"] = Int(date.timeIntervalSince1970.rounded())
        }
    }
    
    static func setFilterList(identifier: String, enabled: Bool) {
        _ = writePreferenceValue { (pref) in
            pref?["\(identifier)_active"] = enabled
        }
    }
    
    static func isFilterListEnabled(identifier: String) -> Bool {
        return readPreferenceValue(of: "\(identifier)_active") ?? false
    }
    
    static func setFilterList(identifier: String, rulesCount: Int) {
        _ = writePreferenceValue { (pref) in
            pref?[identifier] = rulesCount
        }
    }
    
    static func isFilterListSaved(identifier: String) -> Bool {
        let isSaved: Bool? = readPreferenceValue(of: "\(identifier)_active")
        return isSaved != nil
    }
    
    static func filterListRulesCount(identifier: String) -> Int {
        return readPreferenceValue(of: identifier) ?? 0
    }
    
    static func setPauseBlocking(_ pause: Bool) {
        _ = writePreferenceValue { (pref) in
            pref?["PAUSE_BLOCKING"] = pause
        }
    }
    
    static func setOperatingSystem(_ os: String) {
        _ = writePreferenceValue { (pref) in
            pref?["OS"] = os
        }
    }
    
    static func setOperatingSystemVersion(_ osVersion: String) {
        _ = writePreferenceValue { (pref) in
            pref?["OS_VERSION"] = osVersion
        }
    }
    
    static func setSafariVersion(_ version: String) {
        _ = writePreferenceValue { (pref) in
            pref?["SAFARI_VERSION"] = version
        }
    }
    
    static func setSafariLanguage(_ lang: String) {
        _ = writePreferenceValue { (pref) in
            pref?["SAFARI_LANG"] = lang
        }
    }
    
    static func setUserId(_ userId: String) {
        _ = writePreferenceValue { (pref) in
            pref?["USER_ID"] = userId
        }
    }
    
    static func incrementTotalPings() -> Bool {
        return writePreferenceValue { (pref) in
            pref?["TOTAL_PINGS"] = (totalPings + 1)
        }
    }
    
    static func setLastPingDate(_ date: Date) -> Bool {
        return writePreferenceValue { (pref) in
            pref?["LAST_PING_DATE"] = Int(date.timeIntervalSince1970.rounded())
        }
    }

    static func setConvertedRulesToIfTop(_ value: Bool) {
        _ = writePreferenceValue { (pref) in
            pref?["CONVERTED_RULES_TO_IF_TOP"] = value
        }
    }

    static func setPurchasedProductId(_ productId: String) {
        _ = writePreferenceValue { (pref) in
            pref?["PURCHASED_PRODUCT_ID"] = productId
        }
    }

    static func removePurchasedProductId() {
        _ = writePreferenceValue { (pref) in
            pref?["PURCHASED_PRODUCT_ID"] = nil
        }
    }
    
    static func setUpgradeUnlocked(_ value: Bool) {
        _ = writePreferenceValue { (pref) in
            pref?["WHITELIST_WIZARD_UNLOCKED"] = value
        }
    }
}
