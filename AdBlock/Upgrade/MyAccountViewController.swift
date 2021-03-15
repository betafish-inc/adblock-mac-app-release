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

class MyAccountViewController: NSViewController {
    @IBOutlet weak var purchaseTitle: NSTextField!
    @IBOutlet weak var purchaseDescription: NSTextField!
    @IBOutlet weak var purchaseInfo: NSTextField!
    
    private var product = UpgradeInfo()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        getProduct()
    }
    
    private func getProduct() {
        product.loadProduct {[weak self] in
            guard let strongSelf = self else { return }
            if let upgradeProduct = strongSelf.product.upgradeProduct {
                DispatchQueue.main.async {
                    strongSelf.purchaseTitle.stringValue = upgradeProduct.localizedTitle
                    strongSelf.purchaseDescription.stringValue = upgradeProduct.localizedDescription
                }
            } else {
                DispatchQueue.main.async {
                    let message = NSLocalizedString("load.product.fail.message", comment: "")
                    AlertUtil.displayNotification(title: NSLocalizedString("load.product.fail.title", comment: ""), message: message)
                    AlertUtil.toast(in: strongSelf.view, message: message)
                }
            }
        }
        
        if UserPref.purchasedProductId != nil {
            let receiptValidator = ReceiptValidator()
            let validationResult = receiptValidator.validateReceipt()
            switch validationResult {
            case .success(let parsedReceipt):
                let purchaseDate = parsedReceipt.inAppPurchaseReceipts?[0].originalPurchaseDate ?? Date.init()
                let formattedDate = DateFormatter.localizedString(from: purchaseDate, dateStyle: DateFormatter.Style.long, timeStyle: DateFormatter.Style.long)
                DispatchQueue.main.async {[weak self] in
                    self?.purchaseInfo.stringValue = NSLocalizedString("purchase.date", comment: "") + formattedDate
                }
            case .error(let error):
                SwiftyBeaver.error("  validateReceipt error \(error)")
            }
        } else {
            DispatchQueue.main.async {[weak self] in
                self?.purchaseInfo.stringValue = NSLocalizedString("purchase.date", comment: "")
            }
        }
    }
}
