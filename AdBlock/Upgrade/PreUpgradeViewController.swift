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

protocol PreUpgradeVCDelegate: class {
    func purchaseComplete()
}

class PreUpgradeViewController: NSViewController {
    @IBOutlet weak var upgradeNowButton: Button!
    @IBOutlet weak var getMoreDescription: NSTextField!
    
    weak var delegate: PreUpgradeVCDelegate?
    
    private var product = UpgradeInfo()
    private let numberFormatter = NumberFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.numberStyle = .currency
        
        getProduct()
    }
    
    private func alertUser(titleKey: String, messageKey: String, errorMessage: String? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {[weak self] in
            let message = NSLocalizedString(messageKey, comment: "") + (errorMessage ?? "")
            AlertUtil.displayNotification(title: NSLocalizedString(titleKey, comment: ""), message: message)
            guard let strongSelf = self else { return }
            AlertUtil.toast(in: strongSelf.view, message: message)
        }
    }
    
    private func getProduct() {
        product.loadProduct {[weak self] in
            guard let strongSelf = self else { return }
            if let upgradeProduct = strongSelf.product.upgradeProduct {
                strongSelf.numberFormatter.locale = upgradeProduct.priceLocale
                strongSelf.numberFormatter.currencySymbol = upgradeProduct.priceLocale.currencySymbol
                let formattedPrice = "<b>\(strongSelf.numberFormatter.string(from: upgradeProduct.price) ?? "$4.99")</b>"
                let myString = "\(String(format: NSLocalizedString("upgrade.only", comment: ""), formattedPrice)). \(NSLocalizedString("upgrade.more.soon", comment: ""))"
                strongSelf.getMoreDescription.attributedStringValue = myString.convertHTML(size: 15)
                strongSelf.upgradeNowButton.isEnabled = true
            } else {
                strongSelf.alertUser(titleKey: "load.product.fail.title", messageKey: "load.product.fail.message")
            }
        }
    }
    
    private func handlePurchaseSuccess(logMessage: String, alertTitle: String, alertMessage: String) {
        product.upgradeSuccess(logMessage)
        self.alertUser(titleKey: alertTitle, messageKey: alertMessage)
        self.delegate?.purchaseComplete()
    }
    
    private func handleReceiptValidationError(_ error: IAPError, restore: Bool = false) {
        switch error {
        case .receiptValidationFailed(let errMessage):
            SwiftyBeaver.error(" receiptValidationFailed: \(errMessage)")
        default:
            SwiftyBeaver.error("Unknown receipt validation error: \(error)")
        }
        if restore {
            self.alertUser(titleKey: "receipt.fail.title", messageKey: "receipt.fail.message")
        } else {
            self.alertUser(titleKey: "restore.receipt.error.title", messageKey: "restore.receipt.error.message")
        }
    }
    
    private func upgradeNowClickHandler(_ retryCount: Int) {
        if let prodID = product.upgradeProduct?.productIdentifier {
            IAPManager.shared.purchase(product: prodID) {[weak self] (err, _) in
                guard let strongSelf = self else { return }
                // Handle purchase error
                if let error = err {
                    switch error {
                    case .other(let err):
                        SwiftyBeaver.error("Error in purchase: \(err)")
                        strongSelf.alertUser(titleKey: "purchase.error.title", messageKey: "purchase.error.message", errorMessage: err.localizedDescription)
                    case .paymentFailed(let skErrorCode):
                        SwiftyBeaver.error("Payment failed error: \(skErrorCode)")
                        strongSelf.alertUser(titleKey: "purchase.fail.title", messageKey: "purchase.fail.message", errorMessage: "\(skErrorCode)")
                    case .cancelledPurchase:
                        SwiftyBeaver.debug("User has cancelled the purchase")
                        strongSelf.alertUser(titleKey: "purchase.cancelled.title", messageKey: "purchase.cancelled.message")
                    case .invalidIdentifiers(let identifier):
                        SwiftyBeaver.error("Invalid IAP identifier: \(identifier)")
                        strongSelf.alertUser(titleKey: "purchase.id.invalid.title", messageKey: "purchase.id.invalid.message")
                    default:
                        SwiftyBeaver.error("Remaining error cases aren't used for purchase.")
                    }
                    return
                }
                
                IAPManager.shared.validateReceipt { (err, parsedReceipt) in
                    if let error = err {
                        strongSelf.handleReceiptValidationError(error)
                        return
                    }
                
                    let receiptCreation = parsedReceipt?.receiptCreationDate
                    let originalPurchase = parsedReceipt?.inAppPurchaseReceipts?[0].originalPurchaseDate
                    let timeDiff = receiptCreation?.timeIntervalSince(originalPurchase ?? Date.init(timeIntervalSinceNow: 1000))
                    let message = abs(timeDiff ?? 0) > 10.0 ? "purchase_restored" : "upgrade_purchased"
                    strongSelf.handlePurchaseSuccess(logMessage: message, alertTitle: "purchase.thankyou.title", alertMessage: "purchase.thankyou.message")
                }
            }
        } else if retryCount == 0 {
            getProduct()
            upgradeNowClickHandler(1)
        }
    }
    
    @IBAction func upgradeNowButtonClicked(_ sender: Any) {
        upgradeNowClickHandler(0)
    }
    
    @IBAction func restorePurchaseClicked(_ sender: Any) {
        IAPManager.shared.restorePurchases {[weak self] (err, purchases) in
            if let error = err {
                switch error {
                case .restorePurchaseFailed(let fullError):
                    SwiftyBeaver.error("Restore purchase failed. " + fullError.localizedDescription)
                    if !fullError.localizedDescription.isEmpty {
                        self?.alertUser(titleKey: "restore.failed.title", messageKey: "restore.failed.message.error", errorMessage: fullError.localizedDescription)
                    } else {
                        self?.alertUser(titleKey: "restore.failed.title", messageKey: "restore.failed.message")
                    }
                default:
                    SwiftyBeaver.error("Remaining error cases aren't used for restore purchase.")
                    self?.alertUser(titleKey: "restore.failed.title", messageKey: "restore.failed.message")
                }
                return
            }
            
            if purchases?.isEmpty ?? true {
                SwiftyBeaver.debug("No matching purchases found")
                self?.alertUser(titleKey: "restore.no.match.title", messageKey: "restore.no.match.message")
                return
            }
            
            IAPManager.shared.validateReceipt { (err, _) in
                guard let strongSelf = self else { return }
                if let error = err {
                    strongSelf.handleReceiptValidationError(error, restore: true)
                    return
                }
                
                for purchase in purchases ?? [] where strongSelf.product.upgradeProduct?.productIdentifier == purchase.productId {
                    strongSelf.handlePurchaseSuccess(logMessage: "purchase_restored", alertTitle: "purchase.restore.title", alertMessage: "purchase.restore.message")
                    return
                }
                SwiftyBeaver.debug("No matching purchases found")
                strongSelf.alertUser(titleKey: "restore.no.match.title", messageKey: "restore.no.match.message")
            }
        }
    }
}
