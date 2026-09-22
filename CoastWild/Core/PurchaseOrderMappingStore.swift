import Foundation

public struct PurchaseOrderMappingStore {
    private let defaults: UserDefaults
    private let keyPrefix: String

    public init(defaults: UserDefaults, keyPrefix: String = "com.coastwild.iap.order.") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    @discardableResult
    public func stage(orderID: String, forProductID productID: String) -> Bool {
        let key = pendingKey(for: productID)
        if let pendingOrderID = defaults.string(forKey: key), !pendingOrderID.isEmpty {
            return false
        }
        defaults.set(orderID, forKey: key)
        return true
    }

    public func cancelPending(productID: String) {
        defaults.removeObject(forKey: pendingKey(for: productID))
    }

    public func associate(orderID: String, transactionID: String) {
        defaults.set(orderID, forKey: transactionKey(for: transactionID))
    }

    public func resolveForUpdate(transactionID: String, productID: String) -> String? {
        if let orderID = orderID(forTransactionID: transactionID) {
            let pendingKey = pendingKey(for: productID)
            if defaults.string(forKey: pendingKey) == orderID {
                defaults.removeObject(forKey: pendingKey)
            }
            return orderID
        }

        let pendingKey = pendingKey(for: productID)
        guard let orderID = defaults.string(forKey: pendingKey) else {
            return nil
        }

        associate(orderID: orderID, transactionID: transactionID)
        defaults.removeObject(forKey: pendingKey)
        return orderID
    }

    public func orderID(forTransactionID transactionID: String) -> String? {
        defaults.string(forKey: transactionKey(for: transactionID))
    }

    public func restoredTransaction(productID: String, transactionID: String, signedData: String) -> StoreTransaction {
        StoreTransaction(
            productID: productID,
            transactionID: transactionID,
            signedData: signedData,
            orderID: orderID(forTransactionID: transactionID)
        )
    }

    public func finish(transactionID: String) {
        defaults.removeObject(forKey: transactionKey(for: transactionID))
    }

    private func pendingKey(for productID: String) -> String {
        "\(keyPrefix)pending.\(productID)"
    }

    private func transactionKey(for transactionID: String) -> String {
        "\(keyPrefix)\(transactionID)"
    }
}
