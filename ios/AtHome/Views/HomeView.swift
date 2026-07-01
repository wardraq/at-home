import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @State private var alertMessage: String?

    private var engine: SyncEngine { appModel.syncEngine }

    var body: some View {
        VStack(spacing: 20) {
            statsCard

            if engine.isSyncing {
                VStack(spacing: 8) {
                    ProgressView(value: progressValue)
                    Text("同步中 \(engine.progress.completed)/\(engine.progress.total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button(engine.isSyncing ? "同步中..." : "立即同步") {
                Task { await engine.sync() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(engine.isSyncing)

            if let summary = engine.lastSummary {
                Text(summary.message)
                    .font(.footnote)
                    .foregroundStyle(summary.failed > 0 ? .red : .secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("AtHome")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("设置") {
                    SettingsView()
                }
            }
        }
        .refreshable {
            await engine.refreshStats()
        }
        .task {
            await engine.refreshStats()
        }
        .onChange(of: engine.lastSummary?.message) { _, newValue in
            if let newValue, engine.lastSummary?.failed ?? 0 > 0 {
                alertMessage = newValue
            }
        }
        .alert("同步", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var progressValue: Double {
        guard engine.progress.total > 0 else { return 0 }
        return Double(engine.progress.completed) / Double(engine.progress.total)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            statRow("手机照片", engine.stats.phoneCount)
            statRow("已同步", engine.stats.syncedCount)
            statRow("待同步", engine.stats.pendingCount)
            statRow("已归档", engine.stats.archivedCount)
            if engine.stats.skippedCount > 0 {
                statRow("跳过（未在本机）", engine.stats.skippedCount)
            }
            if let last = engine.stats.lastSyncAt {
                HStack {
                    Text("上次同步")
                    Spacer()
                    Text(last.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func statRow(_ title: String, _ value: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value) 张")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}
