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
import SafariServices
import StoreKit

private enum TabItem: Int {
    case upgradeUnavailableTab = 0
    case preUpgradeTab = 1
    case myAccountTab = 2
}
    
class UpgradeViewController: NSTabViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let preUpgradeTVItem = tabViewItems[1] as NSTabViewItem
        if let preUpgradeVC = preUpgradeTVItem.viewController as? PreUpgradeViewController {
            preUpgradeVC.delegate = self
        }
        
        if !SFSafariServicesAvailable(SFSafariServicesVersion.version11_0) || !SKPaymentQueue.canMakePayments() {
            selectedTabViewItemIndex = TabItem.upgradeUnavailableTab.rawValue
        } else if UserPref.purchasedProductId != nil {
            selectedTabViewItemIndex = TabItem.myAccountTab.rawValue
        } else {
            selectedTabViewItemIndex = TabItem.preUpgradeTab.rawValue
        }
    }
}

extension UpgradeViewController: PreUpgradeVCDelegate {
    func purchaseComplete() {
        DispatchQueue.main.async {[weak self] in
            self?.selectedTabViewItemIndex = TabItem.myAccountTab.rawValue
        }
    }
}
