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

class SectionHelper {
    
    static func defaultSections() -> [Section]? {
        guard let mainMenuSourcePath = Bundle.main.path(forResource: "sections", ofType: "plist") else { return nil }
        guard let sectionArray = NSArray(contentsOfFile: mainMenuSourcePath) as? [[String:AnyObject]] else { return nil }
        var sections: [Section]? = []
        for section in sectionArray {
            let header = section["header"] as? String
            var items: [Item]? = []
            if let itemsArray = section["section"] as? [[String: AnyObject]] {
                // Process and prepare section items
                for item in itemsArray {
                    let id = item["id"] as? String
                    let name = item["name"] as? String ?? ""
                    let active = (item["active"] as? Bool ?? true)
                    
                    // Process and prepare filter list
                    var filterListItems: [Item]? = []
                    
                    if id == Item.WHITELIST_ITEM_ID {
                        filterListItems = dummyWhitelists()
                    } else if let filterList = item["filterlist"] as? [[String: AnyObject]] {
                        for filterListItem in filterList {
                            let status = filterListItem["status"] as? Int
                            guard status ?? 0 == 1 else {
                                continue
                            }
                            
                            let upgrade = filterListItem["upgrade"] as? Bool ?? false
                            if upgrade && !UserPref.isUpgradeUnlocked() {
                                continue
                            }
                            
                            let id = filterListItem["id"] as? String
                            if id == Constants.CUSTOM_FILTER_LIST_ID || id == Constants.ADVANCE_FILTER_LIST_ID {
                                continue
                            }
                            
                            let name = filterListItem["name"] as? String ?? ""
                            let active = (filterListItem["active"] as? Bool ?? true)
                            let desc = filterListItem["desc"] as? String ?? ""
                            let rulesCount = filterListItem["rules_count"] as? Int
                            filterListItems?.append(Item(id: id, name: NSLocalizedString(name, comment: ""), active: active, desc: NSLocalizedString(desc, comment: ""), rulesCount: rulesCount))
                        }
                    }

                    if id == Item.UPGRADE_ITEM_ID && (UserPref.purchasedProductId() != nil) {
                        items?.append(Item(id: id, name: NSLocalizedString("product.account.title", comment: ""), active: active, filterListItems: filterListItems))
                    } else {
                        items?.append(Item(id: id, name: NSLocalizedString(name, comment: ""), active: active, filterListItems: filterListItems))
                    }
                    if let image = item["image"] as? String {
                        items?.last?.image = image
                    }
                }
            }
            sections?.append(Section(header: header, items: items))
        }
        return sections
    }
    
    private static func dummyWhitelists() -> [Item]? {
        let whitelistItems: [Item]? = WhitelistManager.shared.getAllItems()
        return whitelistItems
    }
    
    static func saveSectionItemState(_ item: Item?) {
        UserDefaults.standard.set(item?.active, forKey: item?.id ?? "DUMMY_ID")
    }
    
    static func isSectionItemActive(_ item: Item?) -> Bool {
        return UserDefaults.standard.bool(forKey: item?.id ?? "DUMMY_ID")
    }
    
    static func isSectionItemActive(_ itemId: String?) -> Bool {
        return UserDefaults.standard.bool(forKey: itemId ?? "DUMMY_ID")
    }
}
