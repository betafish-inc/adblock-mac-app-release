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

protocol FilterListTableCellViewDelegate: class {
    func filterListTableCellView(_ cell: FilterListTableCellView, enabledItem item: FilterList?)
    func filterListTableCellView(_ cell: FilterListTableCellView, disabledItem item: FilterList?)
}

class FilterListTableCellView: NSTableCellView, GenericTableConforming {
    @IBOutlet weak var progress: NSProgressIndicator!
    @IBOutlet weak var checkbox: NSButton!
    @IBOutlet weak var label: NSTextField!
    
    static var identifier: NSUserInterfaceItemIdentifier {
        return NSUserInterfaceItemIdentifier(rawValue: "FilterListTableCellView")
    }
    static var cellHeight: CGFloat {
        return 80
    }
    var model: FilterList? {
        didSet {
            progress.isHidden = true
            checkbox.state = model?.active ?? false ? .on : .off
            label.stringValue = model?.name ?? ""
        }
    }
    
    private weak var delegate: FilterListTableCellViewDelegate?
    private var adsEnabled: Bool?
    private var currentFilterListId: String?
    private var assetsManagerStatusObserverRef: Disposable?
    
    override func awakeFromNib() {
        label.preferredMaxLayoutWidth = 0
        label.maximumNumberOfLines = 1
        progress.isHidden = true
        
        assetsManagerStatusObserverRef = AssetsManager.shared.status.didChange.addHandler(target: self, handler: FilterListTableCellView.assetsManagerStatusChageObserver)
    }
    
    func update(_ list: FilterList?, newDelegate: FilterListTableCellViewDelegate?, newAdsEnabled: Bool?) {
        model = list
        delegate = newDelegate
        adsEnabled = newAdsEnabled
        checkbox.state = list?.active ?? false ? .on : .off
        label.stringValue = list?.name ?? ""
        
        let assetManagerStatus = AssetsManager.shared.status.get()
        if list?.id ?? "" == Constants.ALLOW_ADS_FILTER_LIST_ID {
            checkbox.isEnabled = assetManagerStatus == .idle && (adsEnabled ?? true)
            label.isEnabled = assetManagerStatus == .idle && (adsEnabled ?? true)
            label.textColor = {
                if assetManagerStatus == .idle {
                    return (adsEnabled ?? false) ? .black : .gray
                } else {
                    return currentFilterListId == list?.id ? .black : ((adsEnabled ?? false) ? .black : .gray)
                }
            }()
        } else {
            checkbox.isEnabled = assetManagerStatus == .idle
            label.isEnabled = assetManagerStatus == .idle
            label.textColor = .black
        }
    }
    
    func showProgress(_ show: Bool) {
        checkbox.isHidden = show
        progress.isHidden = !show
        show ? progress.startAnimation(nil) : progress.stopAnimation(nil)
    }
    
    private func assetsManagerStatusChageObserver(data: (AssetsManagerStatus, AssetsManagerStatus)) {
        switch data.1 {
        case .mergeRulesStarted:
            DispatchQueue.main.async {[weak self] in
                self?.checkbox.isEnabled = false
            }
        case .mergeRulesCompleted, .mergeRulesError:
            DispatchQueue.main.async {[weak self] in
                self?.checkbox.isEnabled = true
                self?.currentFilterListId = nil
            }
        default:
            SwiftyBeaver.debug("idle")
        }
    }
    
    @IBAction func checkboxClick(_ sender: NSButton) {
        currentFilterListId = model?.id
        if sender.state == .on {
            delegate?.filterListTableCellView(self, enabledItem: model)
        } else {
            delegate?.filterListTableCellView(self, disabledItem: model)
        }
    }
    
    deinit {
        assetsManagerStatusObserverRef?.dispose()
    }
}
