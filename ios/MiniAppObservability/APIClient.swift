import Foundation

actor APIClient {
    private let session: URLSession
    private var lastOrderId: String?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func run(_ scenario: Scenario) async -> APIResult {
        let interactionId = Observability.startInteraction(named: scenario.title)
        Observability.breadcrumb(action: "button_tap", extra: ["scenario": scenario.kind.rawValue])

        let started = Date()
        do {
            let outcome = try await perform(scenario)
            let durationMs = Int(Date().timeIntervalSince(started) * 1000)
            Observability.recordButtonTap(
                scenario,
                success: outcome.isSuccess,
                statusCode: outcome.statusCode,
                durationMs: durationMs
            )
            Observability.stopInteraction(interactionId)
            return APIResult(
                scenario: scenario,
                statusCode: outcome.statusCode,
                durationMs: durationMs,
                requestId: outcome.requestId,
                bodyText: outcome.bodyText,
                isSuccess: outcome.isSuccess,
                createdAt: Date()
            )
        } catch {
            let durationMs = Int(Date().timeIntervalSince(started) * 1000)
            Observability.recordButtonTap(scenario, success: false, statusCode: nil, durationMs: durationMs)
            Observability.stopInteraction(interactionId)
            return APIResult(
                scenario: scenario,
                statusCode: nil,
                durationMs: durationMs,
                requestId: "-",
                bodyText: error.localizedDescription,
                isSuccess: false,
                createdAt: Date()
            )
        }
    }

    private func perform(_ scenario: Scenario) async throws -> (statusCode: Int, requestId: String, bodyText: String, isSuccess: Bool) {
        switch scenario.kind {
        case .health:
            return try await request(path: "/health", method: "GET", action: scenario.kind.rawValue)
        case .createOrder:
            let result = try await request(
                path: "/orders",
                method: "POST",
                action: scenario.kind.rawValue,
                body: ["sku": "demo-item", "quantity": 1]
            )
            rememberOrderId(from: result.bodyText)
            return result
        case .slowOrder:
            let result = try await request(
                path: "/orders/slow",
                method: "POST",
                action: scenario.kind.rawValue,
                body: ["sku": "slow-item", "quantity": 1]
            )
            rememberOrderId(from: result.bodyText)
            return result
        case .fetchOrder:
            guard let lastOrderId else {
                throw APIClientError.noOrderYet
            }
            return try await request(path: "/orders/\(lastOrderId)", method: "GET", action: scenario.kind.rawValue)
        case .serverError:
            return try await request(path: "/chaos/error", method: "POST", action: scenario.kind.rawValue)
        case .dependencyFailure:
            return try await request(
                path: "/chaos/dependency",
                method: "POST",
                action: scenario.kind.rawValue,
                body: ["sku": "fail-item", "quantity": 1]
            )
        }
    }

    private func request(
        path: String,
        method: String,
        action: String,
        body: [String: Any]? = nil
    ) async throws -> (statusCode: Int, requestId: String, bodyText: String, isSuccess: Bool) {
        let url = AppConfig.apiBaseURL.appending(
            path: path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        )
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(UUID().uuidString, forHTTPHeaderField: "x-request-id")
        request.setValue("ios", forHTTPHeaderField: "x-client-platform")
        request.setValue(action, forHTTPHeaderField: "x-client-action")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        let bodyText = prettyJSON(data) ?? String(data: data, encoding: .utf8) ?? ""
        let requestId = http.value(forHTTPHeaderField: "x-request-id") ?? "-"
        return (http.statusCode, requestId, bodyText, (200 ..< 300).contains(http.statusCode))
    }

    private func rememberOrderId(from bodyText: String) {
        guard let data = bodyText.data(using: .utf8),
              let order = try? JSONDecoder().decode(OrderResponse.self, from: data)
        else {
            return
        }
        lastOrderId = order.id
    }

    private func prettyJSON(_ data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
            let text = String(data: pretty, encoding: .utf8)
        else {
            return nil
        }
        return text
    }
}

enum APIClientError: LocalizedError {
    case invalidResponse
    case noOrderYet

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "HTTP レスポンスを解釈できませんでした"
        case .noOrderYet:
            return "先に「注文を作成」を実行してください"
        }
    }
}
