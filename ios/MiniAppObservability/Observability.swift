import Foundation
#if canImport(NewRelic)
import NewRelic
#endif

enum Observability {
    static func startInteraction(named name: String) -> String? {
        #if canImport(NewRelic)
        return NewRelic.startInteraction(withName: name)
        #else
        return nil
        #endif
    }

    static func stopInteraction(_ identifier: String?) {
        #if canImport(NewRelic)
        guard let identifier else {
            return
        }
        NewRelic.stopCurrentInteraction(identifier)
        #endif
    }

    static func breadcrumb(action: String, extra: [String: Any] = [:]) {
        #if canImport(NewRelic)
        var attributes: [String: Any] = [
            "action": action,
            "screen": "lab",
        ]
        extra.forEach { attributes[$0.key] = $0.value }
        NewRelic.recordBreadcrumb(action, attributes: attributes)
        #endif
    }

    static func recordButtonTap(_ scenario: Scenario, success: Bool, statusCode: Int?, durationMs: Int) {
        #if canImport(NewRelic)
        NewRelic.recordCustomEvent(
            "ButtonTap",
            name: scenario.kind.rawValue,
            attributes: [
                "title": scenario.title,
                "path": scenario.subtitle,
                "success": success,
                "statusCode": statusCode ?? 0,
                "durationMs": durationMs,
            ]
        )
        #endif
    }
}
