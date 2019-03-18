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

class AssetMerger: NSObject {
    static let shared: AssetMerger = AssetMerger()
    
    private override init() {}
    
    var status: AssetMergerStatus = .idle
    
    func start(_ completion: ((AssetMergerStatus)->Void)? = nil) {
        if self.status != .idle {
            return
        }
        
        SwiftyBeaver.debug("[ASSET_MERGER]: Start merging...")
        self.status = .merging
        self.beginMerge() { (mergedFilterLists) in
            self.saveMergedFilterListsInBackground(mergedFilterLists) {
                SwiftyBeaver.debug("[ASSET_MERGER]: Merged filter list is updated successfully with total rules: \(mergedFilterLists?.count ?? 0)")
                self.status = .completed
                completion?(.completed)
                self.status = .idle
            }
        }
    }
    
    private func beginMerge(completion: @escaping ([[String: Any]]?) -> Void ) {
        mergeDefaultFilterListsInBackground() { (mergedFilterLists) in
            SwiftyBeaver.debug("[ASSET_MERGER]: Default filter lists are merged...")
            
            let activeWhitelistRules = WhitelistManager.shared.getActiveWhitelistRules()
            let newMergedRules: [[String: Any]]? = (mergedFilterLists ?? []) + (activeWhitelistRules ?? [])
            
            guard newMergedRules?.count ?? 0 > 0 else {
                let emptyRules: [[String:Any]]? = FileManager.default.readJsonFile(at: Constants.AssetsUrls.emptyRulesUrl)
                completion(emptyRules)
                return
            }
            
            completion(newMergedRules)
        }
    }
    
    private func mergeDefaultFilterListsInBackground(completion: @escaping ([[String: Any]]?) -> Void) {
        SwiftyBeaver.debug("[ASSET_MERGER]: Reading checksums...")
        guard let checksums: [String: String] = FileManager.default.readJsonFile(at: Constants.AssetsUrls.assetsChecksumUrl) else {
            SwiftyBeaver.debug("[ASSET_MERGER]: Checksums not found, nothing to merge...")
            completion([])
            return
        }
        
        let mergedFilterListGroup = DispatchGroup()
        let mergeLock = NSLock()
        var mergedFilterLists: [[String: Any]]? = []
        
        for (key, _) in checksums {
            if FilterListManager.shared.isEnabled(filterListId: key) {
                if key == Constants.ADS_FILTER_LIST_ID && FilterListManager.shared.isEnabled(filterListId: Constants.ALLOW_ADS_FILTER_LIST_ID) {
                    continue
                }
                if key == Constants.CUSTOM_FILTER_LIST_ID || key == Constants.ANTI_CIRCUMVENTION_LIST_ID || key == Constants.ADVANCE_FILTER_LIST_ID {
                    continue
                }
                
                mergedFilterListGroup.enter()
                DispatchQueue.global(qos: .background).async(group: mergedFilterListGroup) {
                    var updatedKey = key
                    if (SFSafariServicesAvailable(SFSafariServicesVersion.version11_0)) {
                        updatedKey = key + "_v2";
                    }
                    let filterListUrl = Constants.AssetsUrls.thirdPartyFolder?.appendingPathComponent("\(updatedKey).json")
                    
                    // Copy bundled version of third party assets, if not found in group
                    if let filterListPath = filterListUrl?.path, !FileManager.default.fileExists(atPath: filterListPath) {
                        if let bundledFilterListPath = Bundle.main.path(forResource: updatedKey, ofType: "json", inDirectory: "Assets/ThirdParty") {
                            do {
                                try FileManager.default.copyItem(atPath: bundledFilterListPath, toPath: filterListPath)
                            } catch {
                                SwiftyBeaver.error("error: \(error)")
                            }
                        }
                    }
                    
                    let filterList: [[String: Any]]? = FileManager.default.readJsonFile(at: filterListUrl)
                    mergeLock.lock()
                    mergedFilterLists = (mergedFilterLists ?? []) + (filterList ?? [])
                    mergeLock.unlock()
                    SwiftyBeaver.debug("[ASSET_MERGER]: Merged \(updatedKey), Rules: \(filterList?.count ?? 0), Total Rules: \(mergedFilterLists?.count ?? 0)")
                    mergedFilterListGroup.leave()
                }
            }
        }
        
        mergedFilterListGroup.notify(queue: .main) {
            completion(mergedFilterLists)
        }
    }
    
    private func saveMergedFilterListsInBackground(_ mergedFilterLists: [[String: Any]]?, completion: @escaping ()->Void) {
        DispatchQueue.global(qos: .background).async {
            let contentBlockerDirUrl = Constants.AssetsUrls.contentBlockerFolder
            FileManager.default.createDirectoryIfNotExists(contentBlockerDirUrl, withIntermediateDirectories: true)
            
            let mergedRulesUrl = Constants.AssetsUrls.mergedRulesUrl
            SwiftyBeaver.debug("[MERGED_RULES_FILE_PATH]: \(mergedRulesUrl?.path ?? "NULL")")
            
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
