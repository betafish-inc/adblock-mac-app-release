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

protocol WhitelistTableCellViewDelegate: class {
    func whitelistTableCellView(_ cell: WhitelistTableCellView, enabledItem item: Whitelist?)
    func whitelistTableCellView(_ cell: WhitelistTableCellView, disabledItem item: Whitelist?)
    func whitelistTableCellView(_ cell: WhitelistTableCellView, deleteItem item: Whitelist?)
}

class WhitelistTableCellView: NSTableCellView, GenericTableConforming {
    @IBOutlet weak var progressView: NSProgressIndicator!
    @IBOutlet weak var checkbox: NSButton!
    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var deleteProgress: NSProgressIndicator!
    @IBOutlet weak var deleteButton: NSButton!
    
    static var identifier: NSUserInterfaceItemIdentifier {
        return NSUserInterfaceItemIdentifier(rawValue: "WhitelistTableCellView")
    }
    static var cellHeight: CGFloat {
        return 60
    }
    var model: Whitelist? {
        didSet {
            progressView.isHidden = true
            checkbox.state = model?.active ?? false ? .on : .off
            label.stringValue = model?.id ?? ""
            deleteProgress.isHidden = true
        }
    }
    
    private weak var delegate: WhitelistTableCellViewDelegate?
    private var assetsManagerStatusObserverRef: Disposable?

    override func awakeFromNib() {
        label.preferredMaxLayoutWidth = 0
        label.maximumNumberOfLines = 2
        progressView.isHidden = true
        assetsManagerStatusObserverRef = AssetsManager.shared.status.didChange.addHandler(target: self, handler: WhitelistTableCellView.assetsManagerStatusChageObserver)
    }
    
    func update(_ whitelist: Whitelist?, newDelegate: WhitelistTableCellViewDelegate?) {
        model = whitelist
        delegate = newDelegate
        checkbox.state = whitelist?.active ?? false ? .on : .off
        label.stringValue = whitelist?.name ?? ""
        checkbox.isEnabled = AssetsManager.shared.status.get() == .idle
        deleteButton.isEnabled = checkbox.isEnabled
        showProgress(false)
        showDeleteProgress(false)
    }
    
    func showProgress(_ show: Bool) {
        DispatchQueue.main.async {[weak self] in
            guard let strongSelf = self else { return }
            strongSelf.checkbox.isHidden = show
            strongSelf.progressView.isHidden = !show
            show ? strongSelf.progressView.startAnimation(nil) : strongSelf.progressView.stopAnimation(nil)
        }
    }
    
    func showDeleteProgress(_ show: Bool) {
        DispatchQueue.main.async {[weak self] in
            guard let strongSelf = self else { return }
            strongSelf.deleteProgress.isHidden = !show
            strongSelf.deleteButton.isHidden = show
            show ? strongSelf.deleteProgress.startAnimation(nil) : strongSelf.deleteProgress.stopAnimation(nil)
        }
    }
    
    private func assetsManagerStatusChageObserver(data: (AssetsManagerStatus, AssetsManagerStatus)) {
        switch data.1 {
        case .mergeRulesStarted:
            DispatchQueue.main.async {[weak self] in
                self?.checkbox.isEnabled = false
                self?.deleteButton.isEnabled = false
            }
        case .mergeRulesCompleted, .mergeRulesError:
            DispatchQueue.main.async {[weak self] in
                self?.checkbox.isEnabled = true
                self?.deleteButton.isEnabled = true
            }
        default:
            SwiftyBeaver.debug("idle")
        }
    }
    
    @IBAction func checkboxClick(_ sender: NSButton) {
        if sender.state == .on {
            delegate?.whitelistTableCellView(self, enabledItem: model)
        } else {
            delegate?.whitelistTableCellView(self, disabledItem: model)
        }
    }
    
    @IBAction func deleteClick(_ sender: NSButton) {
        delegate?.whitelistTableCellView(self, deleteItem: model)
    }
    
    deinit {
        assetsManagerStatusObserverRef?.dispose()
    }
}
