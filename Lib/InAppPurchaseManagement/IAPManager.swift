//
//  IAPManager.swift
//  AdBlock
//
//  Created by Brent Montrose on 8/21/18.
//  Copyright © 2018 BetaFish. All rights reserved.
//

import SwiftyStoreKit
import StoreKit
import SwiftyBeaver
import Alamofire

enum IAPError: Error {
    case emptyProductIds
    case invalidIdentifiers(Set<String>)
    case other(Error) // in other cases
    case cancelledPurchase // in case of user cancelled the purchase
    case paymentFailed(SKError.Code) // in case of .clientInvalid, .paymentNotAllowed
    case receiptValidationFailed(String)

    case restorePurchaseFailed
}

class IAPManager: NSObject {
    static let shared: IAPManager = IAPManager()

    private override init() {}

    func initialize() {
        SwiftyStoreKit.completeTransactions(atomically: true) { purchases in
            for purchase in purchases {
                switch purchase.transaction.transactionState {
                case .purchased, .restored:
                    if purchase.needsFinishTransaction {
                        SwiftyStoreKit.finishTransaction(purchase.transaction)
                    }
                case .failed, .purchasing, .deferred:
                    break
                }
            }
        }
    }

    func fetchProducts(with identifiers:Set<String>, completion: @escaping (_ error: IAPError?, _ products: Set<SKProduct>?)->Void) {
        if identifiers.count == 0 {
            completion(IAPError.emptyProductIds, nil)
            return
        }

        SwiftyStoreKit.retrieveProductsInfo(identifiers) { result in
            if let error = result.error {
                SwiftyBeaver.error("IAPManager: Error \(result.error.debugDescription)")
                completion(IAPError.other(error), nil)
                return
            }

            if !result.invalidProductIDs.isEmpty {
                completion(IAPError.invalidIdentifiers(result.invalidProductIDs), nil)
                return
            }

            completion(nil, result.retrievedProducts)
        }
    }

    func restorePurchases(_ completion: @escaping (_ error: IAPError?, _ restoredPurchases: [Purchase]?)->Void) {
        SwiftyStoreKit.restorePurchases(atomically: true) { results in
            for purchase in results.restoredPurchases where purchase.needsFinishTransaction {
                SwiftyStoreKit.finishTransaction(purchase.transaction)
            }

            if results.restoreFailedPurchases.count > 0 {
                SwiftyBeaver.error("Restore Failed: \(results.restoreFailedPurchases)")
                DispatchQueue.main.async { completion(IAPError.restorePurchaseFailed, nil) }
            } else if results.restoredPurchases.count > 0 {
                SwiftyBeaver.debug("Restore Success: \(results.restoredPurchases)")
                DispatchQueue.main.async { completion(nil, results.restoredPurchases) }
            } else {
                SwiftyBeaver.debug("Nothing to Restore")
                DispatchQueue.main.async { completion(nil, []) }
            }
        }
    }

    func purchase(product identifier:String, qty: Int = 1, completion: @escaping (_ error: IAPError?, _ purchase: PurchaseDetails?)->Void) {
        SwiftyStoreKit.purchaseProduct(identifier, quantity: qty, atomically: true) { result in
            switch result {
            case .success(let purchase):
                SwiftyBeaver.debug("IAPManager: Purchase Success \(purchase.productId)")
                completion(nil, purchase)
            case .error(let error):
                switch error.code {
                case .unknown:
                    // Unknown error. Please contact support
                    DispatchQueue.main.async { completion(.other(error), nil) }
                case .clientInvalid, .paymentNotAllowed:
                    // Not allowed to make the payment
                    // The device is not allowed to make the payment
                    DispatchQueue.main.async { completion(.paymentFailed(error.code), nil) }
                case .paymentCancelled:
                    DispatchQueue.main.async { completion(.cancelledPurchase, nil) }
                case .paymentInvalid:
                    // The purchase identifier was invalid
                    DispatchQueue.main.async { completion(.invalidIdentifiers([identifier]), nil) }
                }
            }
        }
    }

    //func validateReceipt(_ completion: @escaping (_ error: IAPError?, _ receipt: ReceiptInfo?)->Void ) {
    func validateReceipt(_ completion: @escaping (_ error: IAPError?, _ receipt: ParsedReceipt?)->Void ) {
        let receiptData = SwiftyStoreKit.localReceiptData
        let receiptString = receiptData?.base64EncodedString(options: [])
        let receiptValidator = ReceiptValidator()
        let validationResult = receiptValidator.validateReceipt()
        switch validationResult {
        case .success(let parsedReceipt):
            SwiftyBeaver.debug("IAPManager: validateReceipt success")
            SwiftyBeaver.debug("IAPManager: validateReceipt \(parsedReceipt.appVersion)")
            SwiftyBeaver.debug("IAPManager: validateReceipt \(parsedReceipt.originalAppVersion)")
            SwiftyBeaver.debug("IAPManager: validateReceipt \(parsedReceipt.receiptCreationDate)")
            SwiftyBeaver.debug("IAPManager: validateReceipt \(parsedReceipt.inAppPurchaseReceipts?.count)")
            SwiftyBeaver.debug("IAPManager: validateReceipt \(parsedReceipt.inAppPurchaseReceipts?[0].originalPurchaseDate)")
            SwiftyBeaver.debug("IAPManager: validateReceipt \(parsedReceipt.inAppPurchaseReceipts?[0].productIdentifier)")
            SwiftyBeaver.debug("IAPManager: validateReceipt \(parsedReceipt.inAppPurchaseReceipts?[0].quantity)")
            SwiftyBeaver.debug("IAPManager: validateReceipt \(parsedReceipt.inAppPurchaseReceipts?[0].quantity)")
            completion(nil, parsedReceipt)
        case .error(let error):
            SwiftyBeaver.debug("IAPManager: validateReceipt error \(error)")
            completion(.receiptValidationFailed("ReceiptValidator: Receipt validation failed."), nil)
        }
    }
}
