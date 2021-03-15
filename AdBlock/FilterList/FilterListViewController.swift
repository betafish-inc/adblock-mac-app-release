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

class FilterListViewController: GenericTableViewController<FilterListTableCellView> {
    @IBOutlet weak var lblLastUpdated: NSTextField!
    @IBOutlet weak var filterListOptionsView: NSBox!
    @IBOutlet weak var lblFilterlistDesc: NSTextField!
    @IBOutlet weak var filterListProgress: NSProgressIndicator!
    
    weak var delegate: RulesListVCDelegate?
    var dataSource = DataSource<FilterList>()
    
    private var adsEnabled: Bool?
    private let mergeNotificationName = Notification.Name(rawValue: "\(Constants.SAFARI_MENU_EXTENSION_IDENTIFIER).merge")
    private var currentFilterListId: String?
    private var updatingFilterLists = false
    private var lastUpdatedDate: Date?
    private var lastUpdatedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = NSLocale.current
        formatter.dateFormat = "MMM dd, yyyy HH:mm a zzz"
        return formatter
    }()

    override func viewDidLoad() {
        disposables.append(contentsOf: [
            dataSource.addHandler(target: self, handler: FilterListViewController.changeHandler),
            AssetsManager.shared.status.didChange.addHandler(target: self, handler: FilterListViewController.assetsManagerStatusChageObserver)
        ])
        super.viewDidLoad()
        
        dataSource.replace(FilterListManager.shared.getEnabledFilterLists() ?? [])
        lastUpdatedDate = UserPref.filterListsUpdatedDate
        updateLastUpdatedDateLabel()
        AssetsManager.shared.downloadDataIfNecessary()
    }
    
    override func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var itemData = dataSource.atRow(row)
        if itemData?.id ?? "" == Constants.ALL_FILTER_LIST_INACTIVE_ITEM_ID {
            return tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "InactiveFilterListTableCellView"), owner: self)
        } else {
            itemData = FilterListManager.shared.fetchAndUpdate(item: itemData)
            if itemData?.id ?? "" == Constants.ADS_FILTER_LIST_ID {
                adsEnabled = itemData?.active ?? false
            }
            
            let filterListItemView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "FilterListTableCellView"), owner: self)
            guard let filterListTableViewItem = filterListItemView as? FilterListTableCellView else { return filterListItemView }
            
            filterListTableViewItem.update(itemData, newDelegate: self, newAdsEnabled: adsEnabled)
            
            if currentFilterListId == itemData?.id, AssetsManager.shared.status.get() != .idle {
                filterListTableViewItem.showProgress(true)
            } else {
                filterListTableViewItem.showProgress(false)
            }
            
            return filterListTableViewItem
        }
    }
    
    func changeHandler(change: ([FilterList], [FilterList])) {
        items = change.1
    }
    
    private func findFilterListCellById(_ filterListId: String?) -> FilterListTableCellView? {
        guard let cellIndex = dataSource.firstIndex(where: { (item) -> Bool in
            return item?.id == filterListId
        }) else { return nil }
        
        return tableView.view(atColumn: 0, row: cellIndex, makeIfNecessary: true) as? FilterListTableCellView
    }
    
    private func assetsManagerStatusChageObserver(data: (AssetsManagerStatus, AssetsManagerStatus)) {
        switch data.1 {
        case .filterUpdateStarted:
            updatingFilterLists = true
            DispatchQueue.main.async {[weak self] in
                self?.filterListProgress.startAnimation(nil)
            }
        case .filterUpdateError:
            let errorMessage = NSLocalizedString("filter.lists.error", comment: "")
            AlertUtil.toast(in: self.view, message: errorMessage, toastType: .error)
            updatingFilterLists = false
        case .filterUpdateCompletedNoChange:
            if updatingFilterLists {
                updatingFilterLists = false
                lastUpdatedDate = Date()
                updateLastUpdatedDateLabel()
                let message = NSLocalizedString("filter.lists.success", comment: "")
                AlertUtil.displayNotification(title: NSLocalizedString("filter.lists.title", comment: ""), message: message)
                AlertUtil.toast(in: self.view, message: message)
            }
        case .mergeRulesStarted:
            if updatingFilterLists {
                DispatchQueue.main.async {[weak self] in
                    self?.filterListProgress.startAnimation(nil)
                }
            }
            if AppMenuBar.lastFilterListMenuOperation > 0 {
                if AppMenuBar.lastFilterListMenuOperation == AppMenuBar.ADS_CLICKED {
                    currentFilterListId = Constants.ADS_FILTER_LIST_ID
                } else if AppMenuBar.lastFilterListMenuOperation == AppMenuBar.ALLOW_ADS_CLICKED {
                    currentFilterListId = Constants.ALLOW_ADS_FILTER_LIST_ID
                } else if AppMenuBar.lastFilterListMenuOperation == AppMenuBar.ANTI_CIRCUMVENTION_CLICKED {
                    currentFilterListId = Constants.ANTI_CIRCUMVENTION_LIST_ID
                }
            }
            DispatchQueue.main.async {[weak self] in
                guard let strongSelf = self else { return }
                let filterListCell = strongSelf.findFilterListCellById(strongSelf.currentFilterListId)
                filterListCell?.showProgress(true)
            }
        case .mergeRulesCompleted:
            if updatingFilterLists {
                updatingFilterLists = false
                lastUpdatedDate = Date()
                updateLastUpdatedDateLabel()
                let message = NSLocalizedString("filter.lists.success", comment: "")
                AlertUtil.displayNotification(title: NSLocalizedString("filter.lists.title", comment: ""), message: message)
                AlertUtil.toast(in: self.view, message: message)
            }
            fallthrough
        case .mergeRulesError:
            updatingFilterLists = false
            DispatchQueue.main.async {[weak self] in
                guard let strongSelf = self else { return }
                let filterListCell = strongSelf.findFilterListCellById(strongSelf.currentFilterListId)
                filterListCell?.showProgress(false)
                strongSelf.currentFilterListId = nil
                AppMenuBar.lastFilterListMenuOperation = 0
                strongSelf.dataSource.replace(FilterListManager.shared.getEnabledFilterLists() ?? [])
            }
            // delay for UX
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: showOrHideFilterListWarning)
            DistributedNotificationCenter.default().post(name: mergeNotificationName, object: nil)
        default:
            SwiftyBeaver.debug("idle")
            DispatchQueue.main.async {[weak self] in
                self?.filterListProgress.stopAnimation(nil)
            }
        }
    }
    
    private func showOrHideFilterListWarning() {
        let itemHasInactiveID: (FilterList?) -> Bool = { $0?.id ?? "" == Constants.ALL_FILTER_LIST_INACTIVE_ITEM_ID }
        
        guard var _ = dataSource.firstIndex(where: { (item) -> Bool in
            return item?.active == true && !itemHasInactiveID(item)
        }) else {
            // show warning
            if dataSource.firstIndex(where: { (item) -> Bool in
                return itemHasInactiveID(item)
            }) != nil { return }
            
            dataSource.insertAtStart(FilterList(id: Constants.ALL_FILTER_LIST_INACTIVE_ITEM_ID, name: "", desc: "", active: true, rulesCount: 0))
            tableView.beginUpdates()
            tableView.insertRows(at: IndexSet(integer: 0), withAnimation: .effectFade)
            tableView.endUpdates()
            tableView.reloadData()
            AlertUtil.displayNotification(title: NSLocalizedString("filter.lists.title", comment: ""),
                                          message: NSLocalizedString("adblock.not.blocking.alert", comment: ""))
            return
        }
        
        // hide warning
        guard let idx = dataSource.firstIndex(where: { (item) -> Bool in
            return itemHasInactiveID(item)
        }) else { return }
        
        tableView.beginUpdates()
        tableView.removeRows(at: IndexSet(integer: idx), withAnimation: .effectFade)
        dataSource.filter { (item) -> Bool in return !itemHasInactiveID(item) }
        tableView.endUpdates()
        AlertUtil.displayNotification(title: NSLocalizedString("filter.lists.title", comment: ""),
                                      message: NSLocalizedString("adblock.blocking.again", comment: ""))
    }
    
    private func updateLastUpdatedDateLabel() {
        lblLastUpdated.stringValue = "\(NSLocalizedString("filter.lists.last.updated", comment: "")) \(lastUpdatedDateFormatter.string(from: lastUpdatedDate ?? Date()))"
    }
    
    @IBAction func updateFilterListButtonClicked(_ sender: Button) {
        AssetsManager.shared.requestFilterUpdate()
    }
}

extension FilterListViewController: FilterListTableCellViewDelegate {
    func filterListTableCellView(_ cell: FilterListTableCellView, enabledItem item: FilterList?) {
        guard FilterListManager.shared.canEnable(filterListId: item?.id ?? "DUMMY") else {
            delegate?.onTooManyRulesActiveError()
            cell.checkbox.state = .off
            return
        }
        
        currentFilterListId = item?.id
        if item?.id ?? "" == Constants.ALLOW_ADS_FILTER_LIST_ID {
            FilterListManager.shared.enable(filterListId: Constants.ADS_FILTER_LIST_ID)
        }
        
        FilterListManager.shared.enable(filterListId: item?.id ?? "DUMMY")
        FilterListManager.shared.callAssetMerge()
    }
    
    func filterListTableCellView(_ cell: FilterListTableCellView, disabledItem item: FilterList?) {
        currentFilterListId = item?.id
        if item?.id ?? "" == Constants.ADS_FILTER_LIST_ID {
            FilterListManager.shared.disable(filterListId: Constants.ALLOW_ADS_FILTER_LIST_ID)
        }
        
        FilterListManager.shared.disable(filterListId: item?.id ?? "DUMMY")
        FilterListManager.shared.callAssetMerge()
    }
}
