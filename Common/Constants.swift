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
import SafariServices

extension URL {
    static let groupStorageFolder: URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.GROUP_IDENTIFIER)
    static let assetsFolder: URL? = groupStorageFolder?.appendingPathComponent("Assets")
    static let thirdPartyFolder: URL? = assetsFolder?.appendingPathComponent("ThirdParty")
    static let contentBlockerFolder: URL? = assetsFolder?.appendingPathComponent("ContentBlocker")
    static let logFolder: URL? = assetsFolder?.appendingPathComponent("Log")
    static let logFile: URL? = logFolder?.appendingPathComponent("log_file.txt")
    static let assetsChecksumFile: URL? = assetsFolder?.appendingPathComponent("assets_checksum.json")
    static let mergedRulesFile: URL? = contentBlockerFolder?.appendingPathComponent("merged_rules.json")
    static let emptyRulesFile: URL? = contentBlockerFolder?.appendingPathComponent("empty_rules.json")
    static let whitelistFile: URL? = assetsFolder?.appendingPathComponent("whitelist.json")
    static let userPreferenceFile: URL? = assetsFolder?.appendingPathComponent("user_preference.json")
    static let filterListTextFile: URL? = assetsFolder?.appendingPathComponent("filter_lists_text.txt")
    
    static func assetURL(asset identifier: String, type: String?) -> URL? {
        var pathComponent = identifier
        if type == "json" {
            pathComponent += "_v2"
        }
        FileManager.default.createDirectoryIfNotExists(.thirdPartyFolder, withIntermediateDirectories: true)
        
        return URL.thirdPartyFolder?.appendingPathComponent("\(pathComponent).\(type ?? "txt")")
    }
    
    static func filterURL(filter identifier: String) -> URL? {
        if identifier == Constants.ADS_FILTER_LIST_ID {
            return URL(string: "https://cdn.adblockcdn.com/filters/easylist_content_blocker_v2.json")
        } else if identifier == Constants.ALLOW_ADS_FILTER_LIST_ID {
            return URL(string: "https://cdn.adblockcdn.com/filters/easylist+exceptionrules_content_blocker_v2.json")
        } else if identifier == Constants.ANTI_CIRCUMVENTION_LIST_ID {
            return URL(string: "https://easylist-downloads.adblockplus.org/abp-filters-anti-cv.txt")
        } else if identifier == Constants.ADVANCE_FILTER_LIST_ID {
            return URL(string: "https://cdn.adblockcdn.com/filters/advance_hiding.txt")
        }
        return nil
    }
}

public struct Constants {
    static let DEBUG_LOG_ENABLED = false

    /// Group Identifier
    static let GROUP_IDENTIFIER = "3KKZV48AQD.com.betafish.adblock-mac"
    static let SAFARI_CONTENT_BLOCKER_EXT_IDENTIFIER = "com.betafish.adblock-mac.SafariContentBlocker"
    static let SAFARI_MENU_EXTENSION_IDENTIFIER = "com.betafish.adblock-mac.SafariMenu"
    
    static let DONATION_PAGE_URL = "https://getadblock.com/mobile/test"
    static let HELP_PAGE_URL = "https://help.getadblock.com/"
    static let ADBLOCK_WEBSITE_URL = "https://getadblock.com"
    
    static let CONTENT_BLOCKING_RULES_LIMIT = 50000
    static let FILTER_LISTS_UPDATE_INTERVAL_SECONDS = 60 * 60 * 24 * 4 // 4 DAYS
    static let ALLOW_ADS_FILTER_LIST_ID = "easylist_exceptionrules_content_blocker"
    static let ADS_FILTER_LIST_ID = "easylist_content_blocker"
    static let ANTI_CIRCUMVENTION_LIST_ID = "anti_circumvention"
    static let CUSTOM_FILTER_LIST_ID = "custom"
    static let ADVANCE_FILTER_LIST_ID = "advance_filters"
    
    static let ANTICIRCUMVENTION_NOT_FIRST_RUN = "anti_circumvention_not_first_run"
    
    static let BUNDLED_FILTER_LISTS_UPDATE_DATE: Date = {
        var components = Calendar.current.dateComponents([], from: Date())
        components.setValue(2018, for: .year)
        components.setValue(05, for: .month)
        components.setValue(01, for: .day)
        components.setValue(12, for: .hour)
        components.setValue(00, for: .minute)
        components.setValue(00, for: .second)
        return Calendar.current.date(from: components) ?? Date()
    }()
    static let DATE_STRING_A_WHILE_AGO = "Sat, 1 Jan 2000 12:00:00 GMT"
    
    /// Observable flag to select whitelist in section when user click on `whitelist` from app menu bar
    static var shouldSelectWhitelist = Observable<Bool>(false)

    static let PING_URL: String = "https://ping.getadblock.com/stats/"

    static let LOG_SERVER_URL: String = "https://log.getadblock.com/v2/record_log.php"
    
    public enum AdBlockError: Error {
        case invalidApiUrl
    }

    public struct Api {
        static let validateReceipt = "/validate-receipt"
    }

    // In-app purchase product ids
    public enum Donate: String {
        case onetimePurchaseAt499 = "com.betafish.adblock.mac.adblock.gold"
    }
    
    static let EMPTY_WHITELIST_ITEM_ID = "EMPTY_WHITELIST"
    static let ALL_FILTER_LIST_INACTIVE_ITEM_ID = "INACTIVE_FILTER_LIST"
}
