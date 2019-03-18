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

enum FilterListManagerStatus {
    case idle
    
    case filterListUpdateStarted
    case filterListUpdateCompleted
}

class FilterListManager: NSObject {
    static let shared: FilterListManager = FilterListManager()
    private override init() {
        super.init()
    }
    
    var status: Observable<FilterListManagerStatus> = Observable(.idle)
    
    func initialize() {
        updateDefaultStateIfNotDone()
    }
    
    func canEnable(filterListId: String) -> Bool {
        let activeRulesCount = activeFilterListsRulesCount(exceptionRulesId: filterListId)
        let currentFilterListRulesCount = UserPref.filterListRulesCount(identifier: filterListId)
        return (activeRulesCount + currentFilterListRulesCount) <= Constants.CONTENT_BLOCKING_RULES_LIMIT
    }
    
    func enable(filterListId: String) {
        status.set(newValue: .filterListUpdateStarted)
        UserPref.setFilterList(identifier: filterListId, enabled: true)
        // All "secret" upgrade filter lists should be enabled when the Anti-Circumvention list is enabled
        if filterListId == Constants.ANTI_CIRCUMVENTION_LIST_ID {
            UserPref.setFilterList(identifier: Constants.CUSTOM_FILTER_LIST_ID, enabled: true)
            UserPref.setFilterList(identifier: Constants.ADVANCE_FILTER_LIST_ID, enabled: true)
        }
        status.set(newValue: .filterListUpdateCompleted)
        status.set(newValue: .idle)
    }
    
    func disable(filterListId: String) {
        status.set(newValue: .filterListUpdateStarted)
        UserPref.setFilterList(identifier: filterListId, enabled: false)
        // All "secret" upgrade filter lists should be disabled when the Anti-Circumvention list is disabled
        if filterListId == Constants.ANTI_CIRCUMVENTION_LIST_ID {
            UserPref.setFilterList(identifier: Constants.CUSTOM_FILTER_LIST_ID, enabled: false)
            UserPref.setFilterList(identifier: Constants.ADVANCE_FILTER_LIST_ID, enabled: false)
        }
        status.set(newValue: .filterListUpdateCompleted)
        status.set(newValue: .idle)
    }
    
    func fetchAndUpdate(item: Item?) {
        item?.active = UserPref.isFilterListEnabled(identifier: item?.id ?? "DUMMY")
        item?.rulesCount = UserPref.filterListRulesCount(identifier: item?.id ?? "DUMMY")
    }
    
    func saveState(item: Item?) {
        UserPref.setFilterList(identifier: item?.id ?? "DUMMY", enabled: item?.active ?? false)
        UserPref.setFilterList(identifier: item?.id ?? "DUMMY", rulesCount: item?.rulesCount ?? 0)
    }
    
    func updateRulesCount(completion: @escaping (Bool) -> Void) {
        SwiftyBeaver.debug("[FILTER_LIST_MANAGER]: Reading checksums...")
        guard let checksums: [String: String] = FileManager.default.readJsonFile(at: Constants.AssetsUrls.assetsChecksumUrl) else {
            SwiftyBeaver.debug("[FILTER_LIST_MANAGER]: Checksums not found, nothing to count...")
            completion(false)
            return
        }
        
        let group = DispatchGroup()
        
        for (key, _) in checksums {
            group.enter()
            DispatchQueue.global(qos: .background).async(group: group) {
                var updatedKey = key
                if (SFSafariServicesAvailable(SFSafariServicesVersion.version11_0)) {
                    updatedKey = key + "_v2";
                }
                let filterListUrl = Constants.AssetsUrls.thirdPartyFolder?.appendingPathComponent("\(updatedKey).json")
                let filterList: [[String: Any]]? = FileManager.default.readJsonFile(at: filterListUrl)
                SwiftyBeaver.debug("[FILTER_LIST_MANAGER]: \(updatedKey) (\(filterList?.count ?? 0) Rules)")
                // save the original key, not the "updatedKey", we don't need to expose that version of the content blocking rules to UserPrefs
                UserPref.setFilterList(identifier: key, rulesCount: filterList?.count ?? 0)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(true)
        }
    }
    
    func isEnabled(filterListId: String) -> Bool {
        return UserPref.isFilterListEnabled(identifier: filterListId)
    }
    
    func callAssetMerge() {
        AssetsManager.shared.requestMerge()
    }
    
    private func activeFilterListsRulesCount(exceptionRulesId: String) -> Int {
        SwiftyBeaver.debug("[FILTER_LIST_MANAGER]: Reading checksums...")
        guard let checksums: [String: String] = FileManager.default.readJsonFile(at: Constants.AssetsUrls.assetsChecksumUrl) else {
            SwiftyBeaver.debug("[FILTER_LIST_MANAGER]: Checksums not found, nothing to count...")
            return 0
        }
        
        var count = 0
        
        for (key, _) in checksums {
            if isEnabled(filterListId: key) {
                if (key == Constants.ADS_FILTER_LIST_ID || key == Constants.ALLOW_ADS_FILTER_LIST_ID) && (exceptionRulesId == Constants.ALLOW_ADS_FILTER_LIST_ID || exceptionRulesId == Constants.ADS_FILTER_LIST_ID) {
                    continue
                } else if (key == Constants.ADS_FILTER_LIST_ID && isEnabled(filterListId: Constants.ALLOW_ADS_FILTER_LIST_ID)) {
                    continue
                }
                count = count + UserPref.filterListRulesCount(identifier: key)
            }
        }
        
        return count
    }
    
    private func updateDefaultStateIfNotDone() {
        if UserPref.isBundledAssetsDefaultStateUpdated() {
            return
        }
        
        let mainMenuSourcePath = Bundle.main.path(forResource: "sections", ofType: "plist")
        if let unwrappedMainMenuPath = mainMenuSourcePath, let sectionArray = NSArray(contentsOfFile: unwrappedMainMenuPath) as? [[String:AnyObject]] {
            for section in sectionArray {
                if let itemsArray = section["section"] as? [[String: AnyObject]] {
                    // Process and prepare section items
                    for item in itemsArray {
                        if let filterList = item["filterlist"] as? [[String: AnyObject]] {
                            for filterListItem in filterList {
                                let id = filterListItem["id"] as? String
                                var active = (filterListItem["active"] as? Bool ?? true)
                                let rulesCount = filterListItem["rules_count"] as? Int
                                let upgrade = filterListItem["upgrade"] as? Bool ?? false
                                if upgrade && !UserPref.isUpgradeUnlocked() {
                                    active = false
                                }
                                
                                // Only save state if the filter list isn't
                                if !UserPref.isFilterListSaved(identifier: id ?? "") {
                                    saveState(item: Item(id: id, name: "", active: active, rulesCount: rulesCount))
                                }
                            }
                        }
                    }
                }
            }
            AssetsManager.shared.requestMerge()
            UserPref.setBundledAssetsDefaultStateUpdated(true)
        }
    }
    
}
