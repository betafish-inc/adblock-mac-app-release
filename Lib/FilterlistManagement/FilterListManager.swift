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

struct FilterList {
    let id: String
    let name: String
    let desc: String
    var active: Bool
    var rulesCount: Int
}

class FilterListManager: NSObject {
    static let shared: FilterListManager = FilterListManager()
    
    private override init() {
        super.init()
    }
    
    func initialize() {
        updateDefaultStateIfNotDone()
    }
    
    func getEnabledFilterLists() -> [FilterList]? {
        var filters: [FilterList]?
        if let filtersSourcePath = Bundle.main.path(forResource: "filters", ofType: "plist"),
            let filterArray = NSArray(contentsOfFile: filtersSourcePath) as? [[String: AnyObject]] {
            filters = []
            for filter in filterArray {
                let upgrade = filter["upgrade"] as? Bool ?? false
                if upgrade && !UserPref.isUpgradeUnlocked {
                    continue
                }
                
                let id = filter["id"] as? String ?? ""
                if id == Constants.CUSTOM_FILTER_LIST_ID || id == Constants.ADVANCE_FILTER_LIST_ID {
                    continue
                }
                
                let name = filter["name"] as? String ?? ""
                let active = (filter["active"] as? Bool ?? true)
                let desc = filter["desc"] as? String ?? ""
                filters?.append(FilterList(id: id,
                                           name: NSLocalizedString(name, comment: ""),
                                           desc: NSLocalizedString(desc, comment: ""),
                                           active: active,
                                           rulesCount: 0))
            }
        }
        return filters
    }
    
    func canEnable(filterListId: String) -> Bool {
        let activeRulesCount = activeFilterListsRulesCount(exceptionRulesId: filterListId)
        let currentFilterListRulesCount = UserPref.filterListRulesCount(identifier: filterListId)
        return (activeRulesCount + currentFilterListRulesCount) <= Constants.CONTENT_BLOCKING_RULES_LIMIT
    }
    
    func enable(filterListId: String) {
        UserPref.setFilterList(identifier: filterListId, enabled: true)
        // All "secret" upgrade filter lists should be enabled when the Anti-Circumvention list is enabled
        if filterListId == Constants.ANTI_CIRCUMVENTION_LIST_ID {
            UserPref.setFilterList(identifier: Constants.CUSTOM_FILTER_LIST_ID, enabled: true)
            UserPref.setFilterList(identifier: Constants.ADVANCE_FILTER_LIST_ID, enabled: true)
        }
    }
    
    func disable(filterListId: String) {
        UserPref.setFilterList(identifier: filterListId, enabled: false)
        // All "secret" upgrade filter lists should be disabled when the Anti-Circumvention list is disabled
        if filterListId == Constants.ANTI_CIRCUMVENTION_LIST_ID {
            UserPref.setFilterList(identifier: Constants.CUSTOM_FILTER_LIST_ID, enabled: false)
            UserPref.setFilterList(identifier: Constants.ADVANCE_FILTER_LIST_ID, enabled: false)
        }
    }
    
    func fetchAndUpdate(item: FilterList?) -> FilterList? {
        var newItem = item
        newItem?.active = UserPref.isFilterListEnabled(identifier: item?.id ?? "DUMMY")
        newItem?.rulesCount = UserPref.filterListRulesCount(identifier: item?.id ?? "DUMMY")
        return newItem
    }
    
    fileprivate func saveState(item: FilterList?) {
        UserPref.setFilterList(identifier: item?.id ?? "DUMMY", enabled: item?.active ?? false)
        UserPref.setFilterList(identifier: item?.id ?? "DUMMY", rulesCount: item?.rulesCount ?? 0)
    }
    
    func isEnabled(filterListId: String) -> Bool {
        return UserPref.isFilterListEnabled(identifier: filterListId)
    }
    
    func callAssetMerge() {
        AssetsManager.shared.requestMerge()
    }
    
    private func activeFilterListsRulesCount(exceptionRulesId: String) -> Int {
        guard let checksums: [String: String] = FileManager.default.readJsonFile(at: .assetsChecksumFile) else {
            return 0
        }
        
        var count = 0
        
        for (key, _) in checksums {
            if isEnabled(filterListId: key) {
                if (key == Constants.ADS_FILTER_LIST_ID &&
                    (exceptionRulesId == Constants.ALLOW_ADS_FILTER_LIST_ID || isEnabled(filterListId: Constants.ALLOW_ADS_FILTER_LIST_ID)))
                    || (key == Constants.ALLOW_ADS_FILTER_LIST_ID && exceptionRulesId == Constants.ADS_FILTER_LIST_ID) {
                    continue
                }
                count += UserPref.filterListRulesCount(identifier: key)
            }
        }
        
        return count
    }
    
    private func updateDefaultStateIfNotDone() {
        if UserPref.isBundledAssetsDefaultStateUpdated {
            return
        }
        
        if let filtersSourcePath = Bundle.main.path(forResource: "filters", ofType: "plist"),
            let filterArray = NSArray(contentsOfFile: filtersSourcePath) as? [[String: AnyObject]] {
            for filterListItem in filterArray {
                let id = filterListItem["id"] as? String ?? ""
                var active = (filterListItem["active"] as? Bool ?? true)
                let rulesCount = filterListItem["rules_count"] as? Int ?? 0
                let upgrade = filterListItem["upgrade"] as? Bool ?? false
                if upgrade && !UserPref.isUpgradeUnlocked {
                    active = false
                }
                
                // Only save state if the filter list isn't
                if !UserPref.isFilterListSaved(identifier: id) {
                    saveState(item: FilterList(id: id, name: "", desc: "", active: active, rulesCount: rulesCount))
                }
            }
        }
        
        AssetsManager.shared.requestMerge()
        UserPref.setBundledAssetsDefaultStateUpdated(true)
    }
}
