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
import SwiftyStoreKit
import StoreKit

class UpgradeInfo {
    var upgradeProduct: SKProduct?
    
    init() {
        loadProduct {}
    }
    
    func loadProduct(_ completion: @escaping () -> Void) {
        IAPManager.shared.fetchProducts(with: [Constants.Donate.onetimePurchaseAt499.rawValue]) {[weak self] (_, products) in
            guard let strongSelf = self else { return }
            guard let products = products else {
                SwiftyBeaver.debug("Something went wrong in retrieving product information.")
                return
            }
            
            strongSelf.upgradeProduct = products.filter { $0.productIdentifier == Constants.Donate.onetimePurchaseAt499.rawValue }.first
            completion()
        }
    }
    
    func upgradeSuccess(_ logMessage: String) {
        UserPref.setPurchasedProductId(upgradeProduct?.productIdentifier ?? "missing.identifier")
        UserPref.setUpgradeUnlocked(true)
        SwiftyBeaver.debug(" Purchase successful")
        LogServerManager.recordMessageWithUserID(msg: logMessage)
        UserDefaults.standard.set(true, forKey: Constants.ANTICIRCUMVENTION_NOT_FIRST_RUN)
        FilterListManager.shared.enable(filterListId: Constants.ANTI_CIRCUMVENTION_LIST_ID)
        FilterListManager.shared.callAssetMerge()
    }
}
