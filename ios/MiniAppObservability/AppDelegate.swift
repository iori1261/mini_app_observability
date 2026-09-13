import UIKit
#if canImport(NewRelic)
import NewRelic
#endif

final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if canImport(NewRelic)
        if !AppConfig.newRelicAppToken.isEmpty {
            NewRelic.start(withApplicationToken: AppConfig.newRelicAppToken)
        }
        #endif
        return true
    }
}
