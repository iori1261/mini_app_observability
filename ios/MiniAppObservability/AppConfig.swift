import Foundation

enum AppConfig {
    /// Simulator から Docker 公開ポートへ届くアドレス。
    /// 実機では Mac の LAN IP（例: http://192.168.1.12:8080）に変更する。
    /// その場合は docker-compose.yml のポート公開も 0.0.0.0 に戻す必要がある。
    static var apiBaseURL: URL {
        if let override = environment("API_BASE_URL"), let url = URL(string: override) {
            return url
        }
        return URL(string: "http://127.0.0.1:8080")!
    }

    /// New Relic Mobile の Application Token。
    ///
    /// このファイルは Git に追跡されている。トークンを直接書くと、そのままコミットされて
    /// 公開リポジトリに載る。Xcode の Product > Scheme > Edit Scheme > Run > Arguments で
    /// 環境変数 NEW_RELIC_APP_TOKEN に設定すること。スキームは xcuserdata に保存され、
    /// .gitignore の対象なので追跡されない。
    ///
    /// 空のままでもアプリは動く。その場合 Mobile へは送らず、バックエンドの APM だけ見られる。
    static var newRelicAppToken: String {
        environment("NEW_RELIC_APP_TOKEN") ?? ""
    }

    private static func environment(_ key: String) -> String? {
        guard let value = ProcessInfo.processInfo.environment[key],
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return value
    }
}
