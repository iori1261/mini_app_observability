import Foundation

enum AppConfig {
    /// Simulator から Docker 公開ポートへ届くアドレス。
    /// 実機では Mac の LAN IP（例: http://192.168.1.12:8080）に変更する。
    static let apiBaseURL = URL(string: "http://127.0.0.1:8080")!

    /// New Relic Mobile の Application Token。
    /// 空のままだとエージェントは起動せず、API 呼び出しだけ確認できる。
    static let newRelicAppToken = ""
}
