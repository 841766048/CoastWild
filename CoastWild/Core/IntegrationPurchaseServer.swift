import Foundation

public enum PurchaseServerError: Error, Equatable, Sendable { case missingSession, invalidOrder }

public actor IntegrationPurchaseServer: PurchaseServerProviding {
    private let client: IntegrationAPIClient
    private let sessions: RemoteSessionStore
    public init(client: IntegrationAPIClient, sessions: RemoteSessionStore) { self.client = client; self.sessions = sessions }
    public func createOrder(_ request: PurchaseRequest) async throws -> PurchaseOrder {
        guard let session = await sessions.session() else { throw PurchaseServerError.missingSession }
        let value = try await client.createRecharge(
            RechargeRequest(goodsCode: request.productID, paySource: request.paySource, invitationID: request.invitationID),
            session: session.requestSession
        )
        guard case let .object(object) = value,
              let productID = object["iosProductId"]?.stringValue, !productID.isEmpty,
              let orderID = object["orderId"]?.stringValue, !orderID.isEmpty
        else { throw PurchaseServerError.invalidOrder }
        return PurchaseOrder(orderID: orderID, productID: productID)
    }
    public func verify(orderID: String?, transaction: StoreTransaction) async throws -> EntitlementSnapshot {
        guard let session = await sessions.session() else { throw PurchaseServerError.missingSession }
        _ = try await client.verifyReceipt(
            ReceiptVerificationRequest(orderNumber: orderID, receipt: transaction.signedData, transactionID: transaction.transactionID),
            session: session.requestSession
        )
        return EntitlementSnapshot(productID: transaction.productID, isActive: true)
    }
}
