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

class WhitelistViewController: GenericTableViewController<WhitelistTableCellView> {
    @IBOutlet weak var txtWhitelist: NSTextField!
    
    weak var delegate: RulesListVCDelegate?
    var dataSource = DataSource<Whitelist>()
    
    private var currentWhitelistUrl: String?
    private var deletingWhitelistItem = false
    private let whitelistNotificationName = Notification.Name(rawValue: "\(Constants.SAFARI_MENU_EXTENSION_IDENTIFIER).whitelist")
    private let mergeNotificationName = Notification.Name(rawValue: "\(Constants.SAFARI_MENU_EXTENSION_IDENTIFIER).merge")
    
    override func viewDidLoad() {
        disposables.append(contentsOf: [
            dataSource.addHandler(target: self, handler: WhitelistViewController.whitelistDidChange),
            WhitelistManager.shared.status.didChange.addHandler(target: self, handler: WhitelistViewController.whitelistManagerStatusChageObserver),
            AssetsManager.shared.status.didChange.addHandler(target: self, handler: WhitelistViewController.assetsManagerStatusChageObserver)
        ])
        DistributedNotificationCenter.default().addObserver(self,
                                                            selector: #selector(updateWhitelist),
                                                            name: whitelistNotificationName,
                                                            object: Constants.SAFARI_MENU_EXTENSION_IDENTIFIER)
        super.viewDidLoad()
        
        dataSource.replace(WhitelistManager.shared.getAllItems() ?? [])
    }
    
    override func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let itemData = dataSource.atRow(row)
        if itemData?.id ?? "" == Constants.EMPTY_WHITELIST_ITEM_ID {
            return tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "EmptyWhitelistTableCellView"), owner: self)
        } else {
            let whitelistItemView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "WhitelistTableCellView"), owner: self)
            guard let whitelistCellViewItem = whitelistItemView as? WhitelistTableCellView else { return whitelistItemView }
            
            whitelistCellViewItem.update(itemData, newDelegate: self)
            if currentWhitelistUrl == itemData?.id, AssetsManager.shared.status.get() != .idle {
                deletingWhitelistItem ? whitelistCellViewItem.showDeleteProgress(true) : whitelistCellViewItem.showProgress(true)
            }
            return whitelistCellViewItem
        }
    }
    
    private func whitelistDidChange(change: ([Whitelist], [Whitelist])) {
        self.items = change.1
    }
    
    @objc private func updateWhitelist() {
        let whitelists = WhitelistManager.shared.getAllItems()
        dataSource.replace(whitelists ?? [])
    }
    
    private func whitelistManagerStatusChageObserver(data: (WhitelistManagerStatus, WhitelistManagerStatus)) {
        switch data.1 {
        case .whitelistUpdateCompleted:
            if !deletingWhitelistItem {
                updateWhitelist()
            }
        default:
            SwiftyBeaver.debug("idle")
        }
    }
    
    private func findWhitelistCellByUrl(_ whitelistUrl: String?) -> WhitelistTableCellView? {
        guard let cellIndex = dataSource.firstIndex(where: { (item) -> Bool in
            return item?.id == whitelistUrl
        }) else { return nil }
        
        return tableView.view(atColumn: 0, row: cellIndex, makeIfNecessary: true) as? WhitelistTableCellView
    }
    
    private func assetsManagerStatusChageObserver(data: (AssetsManagerStatus, AssetsManagerStatus)) {
        switch data.1 {
        case .mergeRulesStarted:
            DispatchQueue.main.async {[weak self] in
                guard let strongSelf = self else { return }
                strongSelf.txtWhitelist.isEnabled = false
                let whitelistCell = strongSelf.findWhitelistCellByUrl(strongSelf.currentWhitelistUrl)
                strongSelf.deletingWhitelistItem ? whitelistCell?.showDeleteProgress(true) : whitelistCell?.showProgress(true)
            }
        case .mergeRulesCompleted, .mergeRulesError:
            DispatchQueue.main.async {[weak self] in
                guard let strongSelf = self else { return }
                strongSelf.txtWhitelist.isEnabled = true
                let whitelistCell = strongSelf.findWhitelistCellByUrl(strongSelf.currentWhitelistUrl)
                strongSelf.deletingWhitelistItem ? whitelistCell?.showDeleteProgress(false) : whitelistCell?.showProgress(false)
                strongSelf.currentWhitelistUrl = nil
                strongSelf.deletingWhitelistItem = false
            }
            updateWhitelist()
            DistributedNotificationCenter.default().post(name: mergeNotificationName, object: nil)
        default:
            SwiftyBeaver.debug("idle")
        }
    }
    
    @IBAction func addWebsiteButtonClicked(_ sender: Button) {
        let whitelistText = txtWhitelist.stringValue
        if whitelistText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }
        
        guard whitelistText.isValidUrl() else {
            let errorMessage = NSLocalizedString("whitelisting.enter.valid.url", comment: "")
            AlertUtil.toast(in: self.view, message: errorMessage, toastType: .error)
            return
        }
        
        guard !WhitelistManager.shared.exists(whitelistText, exactMatch: true) else {
            let errorMessage = NSLocalizedString("whitelisting.url.exists", comment: "")
            AlertUtil.toast(in: self.view, message: errorMessage, toastType: .error)
            return
        }
        
        currentWhitelistUrl = WhitelistManager.shared.normalizeUrl(whitelistText)
        WhitelistManager.shared.add(whitelistText)
        txtWhitelist.stringValue = ""
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self, name: whitelistNotificationName, object: Constants.SAFARI_MENU_EXTENSION_IDENTIFIER)
    }
}

extension WhitelistViewController: WhitelistTableCellViewDelegate {
    func whitelistTableCellView(_ cell: WhitelistTableCellView, deleteItem item: Whitelist?) {
        guard let url = item?.id else { return }
        deletingWhitelistItem = true
        currentWhitelistUrl = url
        WhitelistManager.shared.remove(url)
    }
    
    func whitelistTableCellView(_ cell: WhitelistTableCellView, enabledItem item: Whitelist?) {
        guard WhitelistManager.shared.canEnable() else {
            delegate?.onTooManyRulesActiveError()
            cell.checkbox.state = .off
            return
        }
        
        guard let url = item?.id else { return }
        currentWhitelistUrl = item?.id
        WhitelistManager.shared.enable(url)
    }
    
    func whitelistTableCellView(_ cell: WhitelistTableCellView, disabledItem item: Whitelist?) {
        guard let url = item?.id else { return }
        currentWhitelistUrl = item?.id
        WhitelistManager.shared.disable(url)
    }
}
