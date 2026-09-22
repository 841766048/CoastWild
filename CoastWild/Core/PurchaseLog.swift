import Foundation

public struct PurchaseLog: Equatable, Sendable {
    public enum Stage: String, Sendable { case orderStarted, purchasePending, purchaseCancelled, unverified, verificationFailed, completed }
    public let stage: Stage; public let productID: String; public let transactionID: String?; public let errorCode: String?
    public init(stage: Stage, productID: String, transactionID: String? = nil, errorCode: String? = nil) {
        self.stage = stage; self.productID = productID; self.transactionID = transactionID; self.errorCode = errorCode
    }
    public var jsonValue: JSONValue {
        var object: [String: JSONValue] = ["stage": .string(stage.rawValue), "productId": .string(productID)]
        if let transactionID { object["transactionId"] = .string(transactionID) }
        if let errorCode { object["errorCode"] = .string(errorCode) }
        return .object(object)
    }
}
