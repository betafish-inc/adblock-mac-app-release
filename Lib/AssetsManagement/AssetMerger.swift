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

enum AssetMergerStatus {
    case idle
    case merging
    case completed
}

extension UserPref {
    // Returns true only if the list is enabled
    // AND
    // the list is either not the ADS list OR AA is not enabled
    // (since if the ADS list and AA are both enabled, only AA
    // should be merged)
    // AND
    // the list isn't the custom, anti-circumvention, or advanced lists (txt lists)
    static func shouldMergeNonTxtList(_ identifier: String) -> Bool {
        return UserPref.isFilterListEnabled(identifier: identifier) &&
            (identifier != Constants.ADS_FILTER_LIST_ID || !UserPref.isFilterListEnabled(identifier: Constants.ALLOW_ADS_FILTER_LIST_ID)) &&
            identifier != Constants.CUSTOM_FILTER_LIST_ID &&
            identifier != Constants.ANTI_CIRCUMVENTION_LIST_ID &&
            identifier != Constants.ADVANCE_FILTER_LIST_ID
    }
}

class AssetMerger: NSObject {
    static let shared: AssetMerger = AssetMerger()
    
    private override init() {}
    
    var status: AssetMergerStatus = .idle
    
    func start(_ completion: ((AssetMergerStatus) -> Void)? = nil) {
        if status != .idle {
            return
        }
        
        status = .merging
        mergeDefaultFilterListsInBackground {[weak self] (mergedFilterLists) in
            let activeWhitelistRules = WhitelistManager.shared.getActiveWhitelistRules()
            var mergedRules: [[String: Any]]? = (mergedFilterLists ?? []) + (activeWhitelistRules ?? [])
            
            if mergedRules?.isEmpty ?? true {
                mergedRules = FileManager.default.readJsonFile(at: .emptyRulesFile)
            }
            
            self?.saveMergedFilterListsInBackground(mergedRules) {
                SwiftyBeaver.debug("[ASSET_MERGER]: Merged filter list is updated successfully with total rules: \(mergedRules?.count ?? 0)")
                self?.status = .completed
                completion?(.completed)
                self?.status = .idle
            }
        }
    }
    
    private func mergeDefaultFilterListsInBackground(completion: @escaping ([[String: Any]]?) -> Void) {
        let localChecksums = (FileManager.default.readJsonFile(at: .assetsChecksumFile) as [String: String]?)?.filter { UserPref.shouldMergeNonTxtList($0.key) }
        if localChecksums?.isEmpty ?? true {
            completion([])
            return
        }
        
        let mergedFilterListGroup = DispatchGroup()
        let mergeLock = NSLock()
        var mergedFilterLists: [[String: Any]]? = []
        
        localChecksums?.forEach {
            mergedFilterListGroup.enter()
            let identifier = $0.key
            DispatchQueue.global(qos: .background).async(group: mergedFilterListGroup) {
                let filterListUrl = URL.assetURL(asset: identifier, type: "json")
                
                // Copy bundled version of third party assets, if not found in group
                if let filterListPath = filterListUrl?.path, !FileManager.default.fileExists(atPath: filterListPath) {
                    if let bundledFilterListPath = Bundle.main.path(forResource: "\(identifier)_v2", ofType: "json", inDirectory: "Assets/ThirdParty") {
                        do {
                            try FileManager.default.copyItem(atPath: bundledFilterListPath, toPath: filterListPath)
                        } catch {
                            SwiftyBeaver.error("error: \(error)")
                        }
                    }
                }
                
                let filterList: [[String: Any]]? = FileManager.default.readJsonFile(at: filterListUrl)
                // Save rule count
                UserPref.setFilterList(identifier: identifier, rulesCount: filterList?.count ?? 0)
                mergeLock.lock()
                mergedFilterLists = (mergedFilterLists ?? []) + (filterList ?? [])
                SwiftyBeaver.debug("[ASSET_MERGER]: Merged \(identifier), Rules: \(filterList?.count ?? 0), Total Rules: \(mergedFilterLists?.count ?? 0)")
                mergeLock.unlock()
                mergedFilterListGroup.leave()
            }
        }
        
        mergedFilterListGroup.notify(queue: .main) {
            completion(mergedFilterLists)
        }
    }
    
    private func saveMergedFilterListsInBackground(_ mergedFilterLists: [[String: Any]]?, completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .background).async {
            let contentBlockerDirUrl = URL.contentBlockerFolder
            FileManager.default.createDirectoryIfNotExists(contentBlockerDirUrl, withIntermediateDirectories: true)
            
            let mergedRulesUrl = URL.mergedRulesFile
            
            do {
                let mergedRulesData = try JSONSerialization.data(withJSONObject: mergedFilterLists ?? [], options: JSONSerialization.WritingOptions.prettyPrinted)
                if let mergedRulesPath = mergedRulesUrl?.path, FileManager.default.createFile(atPath: mergedRulesPath, contents: mergedRulesData, attributes: nil) {
                    SwiftyBeaver.debug("[UPDATE_MERGED_RULES]: Successful")
                } else {
                    SwiftyBeaver.error("[ERR_UPDATE_MERGED_RULES]: Unable to write merged rules to file")
                }
            } catch {
                SwiftyBeaver.error("[ERR_UPDATE_MERGED_RULES_]: Unable to write merged rules to file")
            }
            
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
