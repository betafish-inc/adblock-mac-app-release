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

extension UserPref {
    // Returns true only if the list is enabled
    // AND
    // the list is the custom, anti-circumvention, or advanced lists (txt lists)
    static func shouldMergeTxtList(_ identifier: String) -> Bool {
        return UserPref.isFilterListEnabled(identifier: identifier) &&
            (identifier == Constants.CUSTOM_FILTER_LIST_ID ||
                identifier == Constants.ANTI_CIRCUMVENTION_LIST_ID ||
                identifier == Constants.ADVANCE_FILTER_LIST_ID)
    }
}

class FilterListsText: NSObject {
    static let shared: FilterListsText = FilterListsText()
    
    private override init() {
        super.init()
        rebuild {}
    }
    
    var status: FilterListTextStatus = .idle
    
    private var advancedHiding: FilterSet?
    private var snippets: FilterSet?
    private var whitelist: FilterSet?
    
    private var filterListsTextQueue = DispatchQueue(label: "filterListsTextQueue")
    
    struct FiltersData {
        var advanceHiding: [Int: SelectorFilter] = [:]
        var snippets: [Int: SnippetFilter] = [:]
        var whitelist: [Int: Filter] = [:]
    }
    
    func getWhitelist() -> FilterSet? {
        var localWhitelist: FilterSet?
        
        filterListsTextQueue.sync {[weak self] in
            localWhitelist = self?.whitelist
        }
        
        return localWhitelist
    }
    
    func getFiltersTextData() -> [String: FilterSet?] {
        var localWhitelist: FilterSet?
        var localSnippets: FilterSet?
        var localAdvancedHiding: FilterSet?
        var returnData: [String: FilterSet?] = [:]
        
        filterListsTextQueue.sync {[weak self] in
            localWhitelist = self?.whitelist
            localSnippets = self?.snippets
            localAdvancedHiding = self?.advancedHiding
        }
        
        returnData["whitelist"] = localWhitelist
        returnData["snippets"] = localSnippets
        returnData["advancedHiding"] = localAdvancedHiding
        
        return returnData
    }
    
    private func setFiltersTextData(newAdvancedHiding: FilterSet?, newSnippets: FilterSet?, newWhitelist: FilterSet?) {
        filterListsTextQueue.sync {[weak self] in
            self?.advancedHiding = newAdvancedHiding
            self?.snippets = newSnippets
            self?.whitelist = newWhitelist
        }
    }
    
    // Rebuild filters based on the current settings and subscriptions.
    func rebuild(completion: @escaping () -> Void) {
        if status != .idle {
            completion()
            return
        }
        
        status = .merging
        mergeTextFilterListsInBackground {[weak self] (mergedFilterText) in
            guard let strongSelf = self else { return }
            if let fileUrl = URL.filterListTextFile,
                (try? mergedFilterText?.write(to: fileUrl, atomically: true, encoding: .utf8)) != nil {
                    SwiftyBeaver.debug("[FILTER_LISTS_TEXT]: Merged text written to file")
            }
            
            if let texts: [String] = mergedFilterText?.split(separator: "\n").map({ (part) -> String in return String(part) }) {
                let filters = strongSelf.splitByType(texts: texts)
                strongSelf.setFiltersTextData(newAdvancedHiding: FilterSet.fromFilters(data: filters.advanceHiding),
                                              newSnippets: FilterSet.fromFilters(data: filters.snippets),
                                              newWhitelist: FilterSet.fromFilters(data: filters.whitelist))
            }
            strongSelf.status = .completed
            strongSelf.status = .idle
            completion()
        }
    }
    
    func processTextFromFile() {
        if let fileUrl = URL.filterListTextFile,
            let text = try? String(contentsOf: fileUrl, encoding: .utf8) {
            let texts: [String] = text.split(separator: "\n").map { (part) -> String in return String(part) }
            let filters = splitByType(texts: texts)
            setFiltersTextData(newAdvancedHiding: FilterSet.fromFilters(data: filters.advanceHiding),
                               newSnippets: FilterSet.fromFilters(data: filters.snippets),
                               newWhitelist: FilterSet.fromFilters(data: filters.whitelist))
        }
    }
    
    private func splitByType(texts: [String]) -> FiltersData {
        // Remove duplicates and empties.
        var unique = Array(Set(texts))
        
        if let index = unique.firstIndex(of: "") {
            unique.remove(at: index)
        }
        var advanceHidingUnmerged: [SelectorFilter] = []
        var exclude: [String: [SelectorFilter]] = [:]
        
        var data = FiltersData()
        
        for text in unique {
            if Filter.isSelectorExcludeFilter(text: text) {
                if let selectorExcludeFilter = Filter.fromText(text: text) as? SelectorFilter,
                    let selector = selectorExcludeFilter.selector {
                        if exclude[selector] == nil {
                            exclude[selector] = []
                        }
                        exclude[selector]?.append(selectorExcludeFilter)
                }
            } else if Filter.isAdvancedSelectorFilter(text: text) {
                if let advancedSelectorFilter = Filter.fromText(text: text) as? SelectorFilter {
                    advanceHidingUnmerged.append(advancedSelectorFilter)
                }
            } else if Filter.isSnippetFilter(text: text) {
                if let snippetFilter = Filter.fromText(text: text) as? SnippetFilter {
                    data.snippets[snippetFilter.id] = snippetFilter
                }
            } else if Filter.isWhitelistFilter(text: text) {
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
        let localChecksums = (FileManager.default.readJsonFile(at: .assetsChecksumFile) as [String: String]?)?.filter { UserPref.shouldMergeTxtList($0.key) }
        if localChecksums?.isEmpty ?? true {
            completion("")
            return
        }
        
        let mergedTextFilterListGroup = DispatchGroup()
        let filterLock = NSLock()
        var filterText: String = ""
        
        localChecksums?.forEach {
            mergedTextFilterListGroup.enter()
            let identifier = $0.key
            DispatchQueue.global(qos: .background).async(group: mergedTextFilterListGroup) {[weak self] in
                guard let strongSelf = self else { return }
                
                if let listUrl = URL.assetURL(asset: identifier, type: "txt"),
                    FileManager.default.fileExists(atPath: listUrl.path),
                    let filterListText = try? String(contentsOf: listUrl, encoding: .utf8) {
                        filterLock.lock()
                        filterText = "\(filterText)\n\(FilterNormalizer.normalizeList(text: filterListText, allowSnippets: strongSelf.snippetsAllowed(forListId: identifier)))"
                        filterLock.unlock()
                }
                
                mergedTextFilterListGroup.leave()
            }
        }
        
        mergedTextFilterListGroup.notify(queue: .main) {
            completion(filterText)
        }
    }
    
    private func snippetsAllowed(forListId: String) -> Bool {
        if forListId == Constants.ANTI_CIRCUMVENTION_LIST_ID || forListId == Constants.CUSTOM_FILTER_LIST_ID {
            return true
        } else {
            return false
        }
    }
}
