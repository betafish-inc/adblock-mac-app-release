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
import SwiftyBeaver

enum FilterListTextStatus {
    case idle
    case merging
    case completed
}

class FilterListsText: NSObject {
    static let shared: FilterListsText = FilterListsText()
    
    private override init() {
        super.init()
        rebuild(completion: {})
    }
    
    var status: FilterListTextStatus = .idle
    
    private var advancedHiding: FilterSet? = nil
    private var snippets: FilterSet? = nil
    private var whitelist: FilterSet? = nil
    
    private var filterListsTextQueue = DispatchQueue(label: "filterListsTextQueue")
    
    struct FiltersData {
        var advanceHiding: [Int: SelectorFilter] = [:]
        var snippets: [Int: SnippetFilter] = [:]
        var whitelist: [Int: Filter] = [:]
    }
    
    func getWhitelist() -> FilterSet? {
        var localWhitelist: FilterSet?
        
        self.filterListsTextQueue.sync {
            localWhitelist = self.whitelist
        }
        
        return localWhitelist
    }
    
    func getFiltersTextData() -> [String: FilterSet?] {
        var localWhitelist: FilterSet?
        var localSnippets: FilterSet?
        var localAdvancedHiding: FilterSet?
        var returnData: [String: FilterSet?] = [:]
        
        self.filterListsTextQueue.sync {
            localWhitelist = self.whitelist
            localSnippets = self.snippets
            localAdvancedHiding = self.advancedHiding
        }
        
        returnData["whitelist"] = localWhitelist
        returnData["snippets"] = localSnippets
        returnData["advancedHiding"] = localAdvancedHiding
        
        return returnData
    }
    
    private func setFiltersTextData(newAdvancedHiding: FilterSet?, newSnippets: FilterSet?, newWhitelist: FilterSet?) {
        self.filterListsTextQueue.sync {
            self.advancedHiding = newAdvancedHiding
            self.snippets = newSnippets
            self.whitelist = newWhitelist
        }
    }
    
    // Rebuild filters based on the current settings and subscriptions.
    func rebuild(completion: @escaping ()->Void) {
        if self.status != .idle {
            completion()
            return
        }
        
        self.status = .merging
        self.mergeTextFilterListsInBackground() { (mergedFilterText) in
            if let fileUrl = Constants.AssetsUrls.filterListTextUrl {
                if (try? mergedFilterText?.write(to: fileUrl, atomically: true, encoding: .utf8)) != nil {
                    SwiftyBeaver.debug("[FILTER_LISTS_TEXT]: Merged text written to file")
                }
            }
            if let texts: [String] = mergedFilterText?.split(separator: "\n").map({ (part) -> String in return String(part) }) {
                let filters = self.splitByType(texts: texts)
                self.setFiltersTextData(newAdvancedHiding: FilterSet.fromFilters(data: filters.advanceHiding), newSnippets: FilterSet.fromFilters(data: filters.snippets), newWhitelist: FilterSet.fromFilters(data: filters.whitelist))
            }
            self.status = .completed
            self.status = .idle
            completion()
        }
    }
    
    func processTextFromFile() {
        if let fileUrl = Constants.AssetsUrls.filterListTextUrl {
            let text = try? String(contentsOf: fileUrl, encoding: .utf8)
            if let texts: [String] = text?.split(separator: "\n").map({ (part) -> String in return String(part) }) {
                let filters = self.splitByType(texts: texts)
                self.setFiltersTextData(newAdvancedHiding: FilterSet.fromFilters(data: filters.advanceHiding), newSnippets: FilterSet.fromFilters(data: filters.snippets), newWhitelist: FilterSet.fromFilters(data: filters.whitelist))
                SwiftyBeaver.debug("[FILTER_LISTS_TEXT]: Merged text processed from file")
            }
        }
    }
    
    private func splitByType(texts: [String]) -> FiltersData {
        // Remove duplicates and empties.
        var unique = Array(Set(texts))
        
        if let index = unique.index(of: "") {
            unique.remove(at: index)
        }
        var advanceHidingUnmerged: [SelectorFilter] = []
        var exclude: [String: [SelectorFilter]] = [:]
        
        var data = FiltersData()
        
        for text in unique {
            if (Filter.isSelectorExcludeFilter(text: text)) {
                if let selectorExcludeFilter = Filter.fromText(text: text) as? SelectorFilter {
                    if let selector = selectorExcludeFilter.selector {
                        if exclude[selector] == nil {
                            exclude[selector] = []
                        }
                        exclude[selector]?.append(selectorExcludeFilter)
                    }
                }
            } else if (Filter.isAdvancedSelectorFilter(text: text)) {
                if let advancedSelectorFilter = Filter.fromText(text: text) as? SelectorFilter {
                    advanceHidingUnmerged.append(advancedSelectorFilter)
                }
            } else if (Filter.isSnippetFilter(text: text)) {
                if let snippetFilter = Filter.fromText(text: text) as? SnippetFilter {
                    data.snippets[snippetFilter.id] = snippetFilter
                }
            } else if (Filter.isWhitelistFilter(text: text)) {
                if let filter = Filter.fromText(text: text) {
                    data.whitelist[filter.id] = filter
                }
            }
        }
        
        for filter in advanceHidingUnmerged {
            if let selector = filter.selector {
                let hider = SelectorFilter.merge(filter: filter, excludeFiltersIn: exclude[selector])
                data.advanceHiding[hider.id] = hider
            }
        }
        return data
    }
    
    private func mergeTextFilterListsInBackground(completion: @escaping (String?) -> Void) {
        SwiftyBeaver.debug("[MY_FILTERS]: Reading checksums...")
        guard let checksums: [String: String] = FileManager.default.readJsonFile(at: Constants.AssetsUrls.assetsChecksumUrl) else {
            SwiftyBeaver.debug("[MY_FILTERS]: Checksums not found, nothing to merge...")
            completion("")
            return
        }
        
        let mergedTextFilterListGroup = DispatchGroup()
        let filterLock = NSLock()
        var filterText: String = ""
        
        for (key, _) in checksums {
            if FilterListManager.shared.isEnabled(filterListId: key) {
                if key == Constants.ADS_FILTER_LIST_ID && FilterListManager.shared.isEnabled(filterListId: Constants.ALLOW_ADS_FILTER_LIST_ID) {
                    continue
                }
                
                mergedTextFilterListGroup.enter()
                DispatchQueue.global(qos: .background).async(group: mergedTextFilterListGroup) {
                    let filterListUrl = Constants.AssetsUrls.thirdPartyFolder?.appendingPathComponent("\(key).txt")
                    
                    if let filterListPath = filterListUrl?.path, FileManager.default.fileExists(atPath: filterListPath) {
                        if let filterListText = try? String(contentsOf: filterListUrl!, encoding: .utf8) {
                            filterLock.lock()
                            filterText = filterText + "\n" + FilterNormalizer.normalizeList(text: filterListText, allowSnippets: self.snippetsAllowed(forListId: key))
                            filterLock.unlock()
                        }
                    }
                    
                    mergedTextFilterListGroup.leave()
                }
            }
        }
        
        mergedTextFilterListGroup.notify(queue: .main) {
            SwiftyBeaver.debug("[MY_FILTERS]: text files merged")
            
            completion(filterText)
        }
    }
    
    private func snippetsAllowed(forListId: String) -> Bool {
        if (forListId == Constants.ANTI_CIRCUMVENTION_LIST_ID) || (forListId == Constants.CUSTOM_FILTER_LIST_ID) {
            return true
        } else {
            return false
        }
    }
}
