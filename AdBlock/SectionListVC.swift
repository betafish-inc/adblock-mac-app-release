//
//  MainMenuVC.swift
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

protocol SectionListVCDelegate {
    func sectionListVC(_ vc: SectionListVC, didSelectSectionItem item: Item)
}

class SectionListVC: NSViewController {

    @IBOutlet weak var collectionView: NSCollectionView!
    
    fileprivate var menus : [[String:AnyObject]]? = nil
    fileprivate var sections : [Section]? = nil
    fileprivate var shouldSelectWhitelistRef: Disposable?
    fileprivate var whitelistManagerStatusObserverRef: Disposable? = nil
    
    var delegate: SectionListVCDelegate? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.wantsLayer = true
        SwiftyBeaver.debug("[SectionListVC] viewDidLoad")
        shouldSelectWhitelistRef = Constants.shouldSelectWhitelist.didChange.addHandler(target: self, handler: SectionListVC.whitelistMenuClickObserve)
        whitelistManagerStatusObserverRef = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: SectionListVC.whitelistManagerStatusChageObserver)
        
        sections = SectionHelper.defaultSections()
        
        if Constants.shouldSelectWhitelist.get() {
            selectSectionItemById(Item.WHITELIST_ITEM_ID)
            Constants.shouldSelectWhitelist.set(newValue: false)
        } else {
            selectSectionItemById("DEFAULT_FILTERLIST")
        }
        if #available(OSX 10.14, *) {
            collectionView.appearance =  NSAppearance(named: .aqua)
        }
    }
    
    func whitelistMenuClickObserve(data: (Bool, Bool)) {
        if data.1 {
            selectSectionItemById(Item.WHITELIST_ITEM_ID)
            Constants.shouldSelectWhitelist.set(newValue: false)
        }
    }

    func reload() {
        sections = SectionHelper.defaultSections()
        selectSectionItemById(Item.UPGRADE_ITEM_ID)
        self.collectionView.reloadData()
    }
    
    deinit {
        shouldSelectWhitelistRef?.dispose()
        whitelistManagerStatusObserverRef?.dispose()
    }
    
    private func selectSectionItemById(_ id: String) {
        var sectionIndex = 0
        var itemIndex = 0
        for (sIndex, section) in (sections ?? []).enumerated() {
            if let idx = section.items?.index(where: { (item) -> Bool in
                return item.id?.uppercased() == id.uppercased()
            }) {
                sectionIndex = sIndex
                itemIndex = idx
                break
            }
        }
        
        let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
        let indexPathSet = Set<IndexPath>(arrayLiteral: indexPath)
        collectionView.deselectItems(at: collectionView.selectionIndexPaths)
        let section = sections?[sectionIndex]
        let item = section?.items?[itemIndex]
        DispatchQueue.main.asyncAfter(deadline: .now()+0.2, execute: {
            self.collectionView.selectItems(at: indexPathSet, scrollPosition: .top)
            if let unwrappedItem = item {
                self.delegate?.sectionListVC(self, didSelectSectionItem: unwrappedItem)
            }
        })
        
    }
    
    private func whitelistManagerStatusChageObserver(data: (WhitelistManagerStatus, WhitelistManagerStatus)) {
        switch data.1 {
        case .whitelistUpdateCompleted:
            let whitelists = WhitelistManager.shared.getAllItems()
            for section in sections ?? [] {
                guard let whitelist = section.items?.filter({ (item) -> Bool in
                    return item.id == Item.WHITELIST_ITEM_ID
                }).first else {
                    continue
                }
                
                whitelist.filterListItems = whitelists
                break
            }
        default:
            SwiftyBeaver.debug("idle")
        }
    }
}

// MARK:- Collection view data source
// MARK:-
extension SectionListVC : NSCollectionViewDataSource {
    
    // Section Header Count
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return sections?.count ?? 0
    }
    
    // Section Header
    /*func collectionView(_ collectionView: NSCollectionView,
                        viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind,
                        at indexPath: IndexPath) -> NSView {
        let view = collectionView.makeSupplementaryView(ofKind: NSCollectionView.SupplementaryElementKind.sectionHeader, withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SectionHeaderView"), for: indexPath) as! SectionHeaderView
        
        let header = self.sections?[indexPath.section].header
        view.sectionTitle.stringValue = header ?? ""
        
        return view
    }*/
    
    // Section Item Count
    func collectionView(_ collectionView: NSCollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        let items = self.sections?[section].items
        return items?.count ?? 0
    }
    
    // Section Item
    func collectionView(_ collectionView: NSCollectionView,
                        itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let itemView = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SectionItemCollectionViewItem"), for: indexPath)
        guard let sectionItemView = itemView as? SectionItemCollectionViewItem else { return itemView }
        
        var items = self.sections?[indexPath.section].items
        let itemData = items?[indexPath.item]
        sectionItemView.delegate = self
        sectionItemView.update(itemData, for: indexPath)
        return itemView
    }
}

// MARK:- Collectin view delegate
// MARK:-
extension SectionListVC : NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView,
                        didSelectItemsAt indexPaths: Set<IndexPath>) {
        if let indexPathSection = indexPaths.first?.section, let indexPathItem = indexPaths.first?.item, let item = self.sections?[indexPathSection].items?[indexPathItem] {
            self.delegate?.sectionListVC(self, didSelectSectionItem: item)
        }
    }
}

// MARK:- Collection view flow layout delegate
// MARK:-
extension SectionListVC : NSCollectionViewDelegateFlowLayout {
    /*func collectionView(_ collectionView: NSCollectionView,
                        layout collectionViewLayout: NSCollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> NSSize {
        return NSSize(width: 1000, height: 32)
    }*/
}

// MARK:- Main menu collection view item delegate
// MARK:-
extension SectionListVC : SectionItemCollectionViewItemDelegate {
    func sectionItem(_ item: Item?, didActive active: Bool, at indexPath: IndexPath) {
        SwiftyBeaver.debug(sections ?? "")
        SectionHelper.saveSectionItemState(item)
    }
}
