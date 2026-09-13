import Foundation

/// SRE が最初に見る 4 指標のうち、このシナリオで動くもの。
enum GoldenSignal: String, Hashable {
    case traffic
    case latency
    case errors
    case setup

    var label: String {
        switch self {
        case .traffic: return "Traffic（量）"
        case .latency: return "Latency（遅さ）"
        case .errors: return "Errors（失敗）"
        case .setup: return "まず動作確認"
        }
    }
}

struct Scenario: Identifiable, Hashable {
    enum Kind: String {
        case health
        case createOrder
        case fetchOrder
        case slowOrder
        case serverError
        case dependencyFailure
        case normalTraffic
        case mixedTraffic
    }

    let kind: Kind
    let title: String
    let subtitle: String
    let signal: GoldenSignal
    /// このボタンを押すとシステム側で何が起きるか。
    let whatHappens: String
    /// New Relic のどの画面を、どの順にたどるか。
    let steps: [String]
    /// そのまま Query your data に貼れる NRQL。
    let nrql: String
    /// 1 回だけ叩くなら 1。負荷シナリオはまとめて叩く件数。
    var requestCount: Int = 1

    var id: String { kind.rawValue }
    var isLoadTest: Bool { requestCount > 1 }
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
    var requestCount: Int = 1
    var successCount: Int = 1
    var failureCount: Int = 0

    var isBatch: Bool { requestCount > 1 }

    var errorRatePercent: Int {
        guard requestCount > 0 else { return 0 }
        return Int((Double(failureCount) / Double(requestCount) * 100).rounded())
    }
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
    /// まず 1 回ずつ押して、画面の場所を覚えるためのシナリオ。
    static let basics: [Scenario] = [
        Scenario(
            kind: .health,
            title: "1. 動いているか確認する",
            subtitle: "GET /health",
            signal: .setup,
            whatHappens: "API に「生きてる?」とだけ聞きます。決済サービスは呼びません。数ミリ秒で終わります。",
            steps: [
                "左メニューの APM & Services（アプリ性能監視）を開く",
                "mini-app-api をクリックする",
                "左の Transactions（処理の一覧）を開く",
                "GET /health が並んでいることを確認する",
            ],
            nrql: """
            SELECT count(*) FROM Transaction
            WHERE appName = 'mini-app-api'
            FACET name SINCE 30 minutes ago
            """
        ),
        Scenario(
            kind: .createOrder,
            title: "2. 注文する（2 サービスをまたぐ）",
            subtitle: "POST /orders → payments /charge",
            signal: .setup,
            whatHappens: "API が注文を受け取り、決済サービス（payments）を HTTP で呼びます。New Relic 上では 2 つのサービスをまたぐ 1 本のトレースになります。",
            steps: [
                "APM & Services で mini-app-api を開く",
                "左の Distributed tracing（分散トレーシング）を開く",
                "一番上のトレースをクリックする",
                "mini-app-api の下に mini-app-payments がぶら下がっていれば成功",
                "Service map（サービス地図）でも 2 つが線でつながって見える",
            ],
            nrql: """
            SELECT count(*) FROM Transaction
            WHERE appName IN ('mini-app-api', 'mini-app-payments')
            FACET appName SINCE 30 minutes ago
            """
        ),
        Scenario(
            kind: .fetchOrder,
            title: "3. 直前の注文を読む",
            subtitle: "GET /orders/:id",
            signal: .setup,
            whatHappens: "さっき作った注文を 1 件読みます。決済は呼びません。下に出る request.id で、New Relic 側の 1 リクエストを名指しできます。",
            steps: [
                "下に出ている request.id をコピーする",
                "左メニューの Query your data（データを問い合わせる）を開く",
                "下の NRQL を貼り、ID を差し替えて実行する",
                "Logs（ログ）でも同じ ID で絞り込める",
            ],
            nrql: """
            SELECT * FROM Transaction
            WHERE request.id = 'ここに request.id'
            SINCE 1 hour ago
            """
        ),
    ]

    /// 障害を意図的に起こして、画面がどう変わるかを見るシナリオ。
    static let failures: [Scenario] = [
        Scenario(
            kind: .slowOrder,
            title: "4. わざと遅くする",
            subtitle: "POST /orders/slow（2 秒待つ）",
            signal: .latency,
            whatHappens: "API の中で 2 秒わざと待ってから決済します。壊れてはいません。「遅いだけ」の状態です。エラー率は上がりません。",
            steps: [
                "APM & Services で mini-app-api を開く",
                "Summary（概要）の Response time（応答時間）が伸びるのを見る",
                "Transactions で POST /orders/slow だけが遅いことを確認する",
                "Distributed tracing でトレースを開き、待っているのが api 側だと確認する",
                "遅いのは決済のせいではない、と言えたら合格",
            ],
            nrql: """
            SELECT average(duration), percentile(duration, 95) FROM Transaction
            WHERE appName = 'mini-app-api'
            FACET name SINCE 30 minutes ago
            """
        ),
        Scenario(
            kind: .serverError,
            title: "5. サーバー側を壊す",
            subtitle: "POST /chaos/error",
            signal: .errors,
            whatHappens: "API が自分で例外を投げて 500 を返します。決済は呼びません。原因は自分のコードの中にあります。",
            steps: [
                "APM & Services で mini-app-api を開く",
                "Summary の Error rate（エラー率）が上がるのを見る",
                "左メニューの Errors inbox（エラー受信箱）を開く",
                "intentional_server_error を選び、Stack trace（落ちた場所）を見る",
                "同じ画面から Logs（ログ）へ飛び、同じ request.id を確認する",
            ],
            nrql: """
            SELECT count(*) FROM Transaction
            WHERE appName = 'mini-app-api' AND error IS true
            FACET request.uri SINCE 1 hour ago
            """
        ),
        Scenario(
            kind: .dependencyFailure,
            title: "6. 決済サービスを落とす",
            subtitle: "POST /chaos/dependency",
            signal: .errors,
            whatHappens: "決済サービスが 503 を返し、API はそれを受けて 502 を返します。API 自体のコードは正常です。悪いのは呼び先です。",
            steps: [
                "APM & Services で mini-app-api を開く",
                "Distributed tracing で失敗したトレースを開く",
                "赤くなっている span が mini-app-payments 側だと確認する",
                "左の External services（外部サービス呼び出し）でも確認できる",
                "「api のバグではなく payments の障害」と説明できたら合格",
            ],
            nrql: """
            SELECT count(*) FROM Transaction
            WHERE error IS true
            FACET appName SINCE 1 hour ago
            """
        ),
    ]

    /// グラフを実際に動かすためのシナリオ。1 回押しただけでは率は読めない。
    static let load: [Scenario] = [
        Scenario(
            kind: .normalTraffic,
            title: "7. 正常な負荷を流す",
            subtitle: "60 リクエストを連続で送る",
            signal: .traffic,
            whatHappens: "健全なリクエストだけを 60 件まとめて送ります。エラーは出ません。Throughput（処理量）だけが山になります。",
            steps: [
                "APM & Services で mini-app-api を開く",
                "Summary の Throughput（1 分あたりの件数）が跳ね上がるのを見る",
                "同時に Error rate が 0% のままなことを確認する",
                "Response time も悪化していなければ「まだ余裕がある」状態",
                "量が増えても壊れない、が正常なスケールの姿",
            ],
            nrql: """
            SELECT rate(count(*), 1 minute) FROM Transaction
            WHERE appName = 'mini-app-api'
            SINCE 30 minutes ago TIMESERIES
            """,
            requestCount: 60
        ),
        Scenario(
            kind: .mixedTraffic,
            title: "8. エラーを混ぜた負荷を流す",
            subtitle: "40 リクエスト中 約 30% を失敗させる",
            signal: .errors,
            whatHappens: "成功と失敗を混ぜて送ります。エラー率が 0% でも 100% でもない、現場に近い数字になります。手元の結果と New Relic の Error rate を見比べてください。",
            steps: [
                "APM & Services で mini-app-api を開く",
                "Summary の Error rate が 30% 前後になるのを見る",
                "下に出る「エラー率」と同じ数字か見比べる",
                "Errors inbox でエラーの種類が 2 つ（500 と 502）あることを確認する",
                "件数ではなく率で語る、が SRE の基本",
            ],
            nrql: """
            SELECT percentage(count(*), WHERE error IS true) FROM Transaction
            WHERE appName = 'mini-app-api'
            SINCE 30 minutes ago TIMESERIES
            """,
            requestCount: 40
        ),
    ]

    /// 負荷シナリオで実際に叩くエンドポイントの並び。
    static func plan(for scenario: Scenario) -> [Kind] {
        switch scenario.kind {
        case .normalTraffic:
            return buildPlan(total: scenario.requestCount) { index in
                switch index % 3 {
                case 0: return .health
                case 1: return .createOrder
                default: return .fetchOrder
                }
            }
        case .mixedTraffic:
            return buildPlan(total: scenario.requestCount) { index in
                switch index % 10 {
                case 3, 7: return .serverError
                case 5: return .dependencyFailure
                case 0, 6: return .health
                default: return .createOrder
                }
            }
        default:
            return [scenario.kind]
        }
    }

    typealias Kind = Scenario.Kind

    private static func buildPlan(total: Int, pick: (Int) -> Kind) -> [Kind] {
        (0 ..< total).map(pick)
    }
}
