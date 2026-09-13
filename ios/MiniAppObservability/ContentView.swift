import SwiftUI

struct ContentView: View {
    @State private var viewModel = LabViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    resultCard
                    scenarioSection("正常系", scenarios: Scenarios.healthy)
                    scenarioSection("障害系", scenarios: Scenarios.chaotic)
                    history
                }
                .padding()
            }
            .navigationTitle("NR 検証ラボ")
            .background(Color(.systemGroupedBackground))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ボタンを押すと Docker 上の API を呼びます。")
            Text("接続先: \(AppConfig.apiBaseURL.absoluteString)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(viewModel.agentStatusText)
                .font(.footnote)
                .foregroundStyle(viewModel.isAgentEnabled ? .green : .orange)
        }
    }

    @ViewBuilder
    private var resultCard: some View {
        if let result = viewModel.latest {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(result.scenario.title)
                        .font(.headline)
                    Spacer()
                    statusBadge(result)
                }
                labeled("HTTP", value: result.statusCode.map(String.init) ?? "接続失敗")
                labeled("時間", value: "\(result.durationMs) ms")
                labeled("request.id", value: result.requestId)
                Text(result.scenario.newRelicHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(result.bodyText)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func scenarioSection(_ title: String, scenarios: [Scenario]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            ForEach(scenarios) { scenario in
                Button {
                    Task { await viewModel.run(scenario) }
                } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(scenario.title)
                                .font(.body.weight(.semibold))
                            Text(scenario.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
            Text("履歴")
                .font(.headline)
            if viewModel.history.isEmpty {
                Text("まだ実行していません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.history) { item in
                    HStack {
                        Circle()
                            .fill(item.isSuccess ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(item.scenario.title)
                        Spacer()
                        Text("\(item.durationMs) ms")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private func labeled(_ title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }

    private func statusBadge(_ result: APIResult) -> some View {
        Text(result.isSuccess ? "成功" : "失敗")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(result.isSuccess ? Color.green : Color.red)
            .background((result.isSuccess ? Color.green : Color.red).opacity(0.12))
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

    var isAgentEnabled: Bool {
        !AppConfig.newRelicAppToken.isEmpty
    }

    var agentStatusText: String {
        isAgentEnabled
            ? "New Relic Mobile: 有効（トークン設定済み）"
            : "New Relic Mobile: 未設定。API 動作確認のみできます"
    }

    func run(_ scenario: Scenario) async {
        runningKind = scenario.kind
        let result = await client.run(scenario)
        latest = result
        history.insert(result, at: 0)
        if history.count > 12 {
            history = Array(history.prefix(12))
        }
        runningKind = nil
    }
}

#Preview {
    ContentView()
}
