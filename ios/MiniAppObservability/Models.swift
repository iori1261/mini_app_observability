import Foundation

struct Scenario: Identifiable, Hashable {
    enum Kind: String {
        case health
        case createOrder
        case fetchOrder
        case slowOrder
        case serverError
        case dependencyFailure
    }

    let kind: Kind
    let title: String
    let subtitle: String
    let newRelicHint: String

    var id: String { kind.rawValue }
}

struct APIResult: Identifiable {
    let id = UUID()
    let scenario: Scenario
    let statusCode: Int?
    let durationMs: Int
    let requestId: String
    let bodyText: String
    let isSuccess: Bool
    let createdAt: Date
}

struct OrderResponse: Decodable {
    let id: String
    let sku: String
    let quantity: Int
    let amount: Int
    let status: String
    let chargeId: String?
    let requestId: String?
    let createdAt: String?
}

enum Scenarios {
    static let healthy: [Scenario] = [
        Scenario(
            kind: .health,
            title: "ヘルスチェック",
            subtitle: "GET /health",
            newRelicHint: "Mobile HTTP と APM の GET /health がすぐ終わる"
        ),
        Scenario(
            kind: .createOrder,
            title: "注文を作成",
            subtitle: "POST /orders → payments /charge",
            newRelicHint: "分散トレースで api → payments の 2 サービスが見える"
        ),
        Scenario(
            kind: .fetchOrder,
            title: "注文を取得",
            subtitle: "GET /orders/:id",
            newRelicHint: "直前の注文 ID で Transaction を絞れる"
        ),
    ]

    static let chaotic: [Scenario] = [
        Scenario(
            kind: .slowOrder,
            title: "遅い注文",
            subtitle: "POST /orders/slow（2秒待ち）",
            newRelicHint: "Mobile の duration と APM の P95 が伸びる"
        ),
        Scenario(
            kind: .serverError,
            title: "サーバーエラー",
            subtitle: "POST /chaos/error",
            newRelicHint: "Errors inbox と error rate が上がる"
        ),
        Scenario(
            kind: .dependencyFailure,
            title: "決済依存の失敗",
            subtitle: "POST /chaos/dependency",
            newRelicHint: "payments の 503 がトレース上の失敗 span になる"
        ),
    ]
}
