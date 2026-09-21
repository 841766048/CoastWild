import Foundation

public enum IAPBridgeError: Error, Equatable, Sendable {
    case unsupported
}

public enum IAPBridgeCommand: Equatable, Sendable {
    case productPrices(JSONValue)
    case iapLog(JSONValue)

    public func javaScript() throws -> String {
        switch self {
        case let .productPrices(value): try JavaScriptCallbackEncoder.productPriceResult(value)
        case let .iapLog(value): try JavaScriptCallbackEncoder.iapLog(value)
        }
    }
}

public protocol IAPBridgeHandling: Sendable {
    func handle(_ message: BridgeMessage) async throws -> [IAPBridgeCommand]
}

public actor IAPBridgeHandler: IAPBridgeHandling {
    public typealias TrackPurchase = @Sendable (PurchaseLogPayload) async -> Void

    private let catalog: ProductCatalog
    private let coordinator: PurchaseCoordinator
    private let trackPurchase: TrackPurchase
    private var isPurchasing = false

    public init(
        catalog: ProductCatalog,
        coordinator: PurchaseCoordinator,
        trackPurchase: @escaping TrackPurchase = { _ in }
    ) {
        self.catalog = catalog
        self.coordinator = coordinator
        self.trackPurchase = trackPurchase
    }

    public func handle(_ message: BridgeMessage) async throws -> [IAPBridgeCommand] {
        switch message {
        case let .getProductPrice(productIDs):
            do {
                return [.productPrices(try await catalog.load(productIDs: productIDs).bridgeValue)]
            } catch {
                return [.iapLog(Self.log(status: "failed", code: "product_price_failed"))]
            }
        case let .openAppPurchase(payload):
            return await purchase(payload)
        case let .logPurchase(payload):
            await trackPurchase(payload)
            return []
        case .onCreateOrder:
            return []
        default:
            throw IAPBridgeError.unsupported
        }
    }

    private func purchase(_ payload: AppPurchasePayload) async -> [IAPBridgeCommand] {
        guard !isPurchasing else {
            return [.iapLog(Self.log(status: "failed", productID: payload.goodsCode, code: "purchase_in_progress"))]
        }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await coordinator.purchase(.init(
                productID: payload.goodsCode,
                paySource: payload.paySource,
                invitationID: payload.invitationID
            ))
            switch result {
            case .purchased:
                return [.iapLog(Self.log(status: "purchased", productID: payload.goodsCode))]
            case .pending:
                return [.iapLog(Self.log(status: "pending", productID: payload.goodsCode))]
            case .cancelled:
                return [.iapLog(Self.log(status: "cancelled", productID: payload.goodsCode))]
            }
        } catch {
            return [.iapLog(Self.log(status: "failed", productID: payload.goodsCode, code: "purchase_failed"))]
        }
    }

    private static func log(status: String, productID: String? = nil, code: String? = nil) -> JSONValue {
        var value: [String: JSONValue] = [
            "event": .string("purchase_bridge"),
            "status": .string(status),
        ]
        if let productID { value["productId"] = .string(productID) }
        if let code { value["code"] = .string(code) }
        return .object(value)
    }
}
