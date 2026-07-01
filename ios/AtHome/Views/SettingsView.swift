import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showClearConfirm = false
    @State private var showUnpairConfirm = false
    @State private var message: String?

    var body: some View {
        List {
            Section("配对信息") {
                if let pairing = appModel.pairing {
                    LabeledContent("服务器", value: pairing.addr)
                    LabeledContent("用户", value: appModel.userName ?? "—")
                    LabeledContent("serverId", value: pairing.serverId)
                        .font(.caption)
                }
            }

            Section("同步") {
                Button("清除同步记录", role: .destructive) {
                    showClearConfirm = true
                }
            }

            Section {
                Button("重新扫码配对") {
                    Task {
                        do {
                            try appModel.unpair()
                        } catch {
                            message = error.localizedDescription
                        }
                    }
                }
            }

            Section("说明") {
                Text("仅同步已下载到本机的照片。iCloud 未下载的照片会被跳过。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
        .confirmationDialog(
            "清除同步记录？",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("清除并重新上传", role: .destructive) {
                clearRecords()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除本地已同步记录，下次同步会重新上传所有照片。可能耗费较长时间和流量，但服务端不会重复保存多份版本。")
        }
        .alert("提示", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func clearRecords() {
        do {
            try appModel.clearSyncRecords()
            message = "同步记录已清除"
            Task { await appModel.syncEngine.refreshStats() }
        } catch {
            message = error.localizedDescription
        }
    }
}
