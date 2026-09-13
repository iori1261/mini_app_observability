import SwiftUI
import UIKit

struct ContentView: View {
    @State private var viewModel = LabViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    howToUse
                    if viewModel.runningKind != nil {
                        runningCard
                    }
                    resultCard
                    scenarioSection(
                        "STEP 1  画面の場所を覚える",
                        note: "まず 1 回ずつ押して、New Relic のどこに出るか探します。",
                        scenarios: Scenarios.basics
                    )
                    scenarioSection(
                        "STEP 2  わざと壊して違いを見る",
                        note: "「遅い」と「失敗」は別ものです。崩れる指標が変わります。",
                        scenarios: Scenarios.failures
                    )
                    scenarioSection(
                        "STEP 3  グラフを動かす",
                        note: "1 回押しただけでは率もグラフも読めません。まとめて送ります。",
                        scenarios: Scenarios.load
                    )
                    history
                }
                .padding()
            }
            .navigationTitle("New Relic 練習ラボ")
            .background(Color(.systemGroupedBackground))
        }
    }

    private var howToUse: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("使い方")
                .font(.headline)
            numbered(1, "下のボタンを押す（Docker の API が動きます）")
            numbered(2, "結果カードの「New Relic で見る手順」どおりに画面をたどる")
            numbered(3, "NRQL をコピーして Query your data に貼る")

            Divider()

            Text("反映まで 1〜3 分かかります。画面右上の時間範囲は Last 30 minutes にしてください。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("接続先: \(AppConfig.apiBaseURL.absoluteString)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(viewModel.agentStatusText)
                .font(.footnote)
                .foregroundStyle(viewModel.isAgentEnabled ? .green : .orange)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var runningCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            if viewModel.progressTotal > 1 {
                Text("送信中 \(viewModel.progress) / \(viewModel.progressTotal)")
            } else {
                Text("実行中…")
            }
            Spacer()
        }
        .font(.subheadline)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var resultCard: some View {
        if let result = viewModel.latest {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.scenario.title)
                            .font(.headline)
                        signalBadge(result.scenario.signal)
                    }
                    Spacer()
                    statusBadge(result)
                }

                resultNumbers(result)

                section("何が起きたか") {
                    Text(result.scenario.whatHappens)
                        .font(.subheadline)
                }

                section("New Relic で見る手順") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(result.scenario.steps.enumerated()), id: \.offset) { index, step in
                            numbered(index + 1, step)
                        }
                    }
                }

                section("貼るだけの NRQL") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.scenario.nrql)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Button {
                            viewModel.copyNRQL(result.scenario)
                        } label: {
                            Label(viewModel.didCopy ? "コピーしました" : "NRQL をコピー", systemImage: "doc.on.doc")
                                .font(.footnote.weight(.semibold))
                        }
                    }
                }

                DisclosureGroup("API の生レスポンス") {
                    Text(result.bodyText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }
                .font(.subheadline)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private func resultNumbers(_ result: APIResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if result.isBatch {
                labeled("送った数", value: "\(result.requestCount) 件")
                labeled("成功 / 失敗", value: "\(result.successCount) / \(result.failureCount)")
                labeled("エラー率", value: "\(result.errorRatePercent) %")
                labeled("かかった時間", value: "\(result.durationMs) ms")
            } else {
                labeled("HTTP", value: result.statusCode.map(String.init) ?? "接続失敗")
                labeled("かかった時間", value: "\(result.durationMs) ms")
                labeled("request.id", value: result.requestId)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func scenarioSection(_ title: String, note: String, scenarios: [Scenario]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(scenarios) { scenario in
                Button {
                    Task { await viewModel.run(scenario) }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(scenario.title)
                                .font(.body.weight(.semibold))
                                .multilineTextAlignment(.leading)
                            Text(scenario.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            signalBadge(scenario.signal)
                        }
                        Spacer()
                        if viewModel.runningKind == scenario.kind {
                            ProgressView()
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.runningKind != nil)
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("実行履歴")
                .font(.headline)
            if viewModel.history.isEmpty {
                Text("まだ実行していません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.history) { item in
                    HStack {
                        Circle()
                            .fill(item.failureCount == 0 ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(item.scenario.title)
                            .lineLimit(1)
                        Spacer()
                        if item.isBatch {
                            Text("エラー率 \(item.errorRatePercent)%")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(item.durationMs) ms")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func numbered(_ index: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(index).")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)
            Text(text)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func labeled(_ title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }

    private func signalBadge(_ signal: GoldenSignal) -> some View {
        let color: Color = {
            switch signal {
            case .traffic: return .blue
            case .latency: return .orange
            case .errors: return .red
            case .setup: return .gray
            }
        }()

        return Text(signal.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func statusBadge(_ result: APIResult) -> some View {
        let text: String
        let color: Color
        if result.isBatch {
            text = "送信完了"
            color = .blue
        } else if result.isSuccess {
            text = "成功"
            color = .green
        } else {
            text = "失敗"
            color = .red
        }

        return Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

@MainActor
@Observable
final class LabViewModel {
    private let client = APIClient()
    var latest: APIResult?
    var history: [APIResult] = []
    var runningKind: Scenario.Kind?
    var progress = 0
    var progressTotal = 0
    var didCopy = false

    var isAgentEnabled: Bool {
        !AppConfig.newRelicAppToken.isEmpty
    }

    var agentStatusText: String {
        isAgentEnabled
            ? "New Relic Mobile: 有効（アプリ側の操作も送信します）"
            : "New Relic Mobile: 未設定。バックエンドの APM だけ見られます"
    }

    func run(_ scenario: Scenario) async {
        didCopy = false
        runningKind = scenario.kind
        progress = 0
        progressTotal = scenario.requestCount

        let result: APIResult
        if scenario.isLoadTest {
            result = await runLoad(scenario)
        } else {
            result = await client.run(scenario)
        }

        latest = result
        history.insert(result, at: 0)
        if history.count > 12 {
            history = Array(history.prefix(12))
        }
        runningKind = nil
        progressTotal = 0
    }

    func copyNRQL(_ scenario: Scenario) {
        UIPasteboard.general.string = scenario.nrql
        didCopy = true
    }

    private func runLoad(_ scenario: Scenario) async -> APIResult {
        let plan = Scenarios.plan(for: scenario)
        let interactionId = Observability.startInteraction(named: scenario.title)
        Observability.breadcrumb(action: "load_test", extra: ["scenario": scenario.kind.rawValue])

        let started = Date()
        var successCount = 0
        var failureCount = 0

        for kind in plan {
            let ok = await client.runOnce(kind)
            if ok {
                successCount += 1
            } else {
                failureCount += 1
            }
            progress += 1
        }

        let durationMs = Int(Date().timeIntervalSince(started) * 1000)
        Observability.recordTrafficRun(
            scenario,
            total: plan.count,
            failures: failureCount,
            durationMs: durationMs
        )
        Observability.stopInteraction(interactionId)

        return APIResult(
            scenario: scenario,
            statusCode: nil,
            durationMs: durationMs,
            requestId: "-",
            bodyText: "\(plan.count) 件を \(durationMs) ms で送信しました。\n成功 \(successCount) 件 / 失敗 \(failureCount) 件。",
            isSuccess: true,
            createdAt: Date(),
            requestCount: plan.count,
            successCount: successCount,
            failureCount: failureCount
        )
    }
}

#Preview {
    ContentView()
}
