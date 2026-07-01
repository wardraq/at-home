import SwiftUI

struct UnpairedView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showScanner = false
    @State private var alertMessage: String?
    @State private var isTesting = false

    #if DEBUG
    @State private var showDebugPair = false
    @State private var debugAddr = "127.0.0.1:6060"
    #endif

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "house.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)

                Text("AtHome")
                    .font(.largeTitle.bold())

                Text("回家的照片，自动存档")
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    Button("扫描配对二维码") {
                        showScanner = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if appModel.pairing != nil {
                        Button(isTesting ? "测试中..." : "测试连接") {
                            Task { await testConnection() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isTesting)
                    }
                }

                if let pairing = appModel.pairing {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("已扫描，待验证")
                            .font(.headline)
                        Text("服务器：\(pairing.addr)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                Spacer()

                #if DEBUG
                Button("调试配对") {
                    showDebugPair = true
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                #endif
            }
            .padding()
            .navigationTitle("配对")
            .sheet(isPresented: $showScanner) {
                QRScannerView { payload in
                    handleScan(payload)
                }
            }
            #if DEBUG
            .sheet(isPresented: $showDebugPair) {
                DebugPairSheet(addr: $debugAddr) { credentials in
                    showDebugPair = false
                    do {
                        try appModel.applyPairing(credentials)
                        alertMessage = "配对信息已保存，请测试连接"
                    } catch {
                        alertMessage = error.localizedDescription
                    }
                }
            }
            #endif
            .alert("提示", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func handleScan(_ data: Data) {
        guard let credentials = PairingCredentials(jsonData: data) else {
            alertMessage = AtHomeError.invalidQRCode.localizedDescription
            return
        }
        do {
            try appModel.applyPairing(credentials)
            alertMessage = "配对信息已保存，请测试连接"
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func testConnection() async {
        isTesting = true
        defer { isTesting = false }
        do {
            let name = try await appModel.testConnection()
            alertMessage = "连接成功，用户：\(name)"
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}

#if DEBUG
struct DebugPairSheet: View {
    @Binding var addr: String
    @State private var serverId = ""
    @State private var userId = ""
    @State private var statusMsg = ""
    @Environment(\.dismiss) private var dismiss
    let onPair: (PairingCredentials) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("服务器地址") {
                    TextField("addr", text: $addr)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    Button("获取 serverId") {
                        Task { await fetchServerId() }
                    }
                    if !serverId.isEmpty {
                        Text("serverId: \(serverId)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                Section("用户 ID") {
                    TextField("usr-xxxx", text: $userId)
                        .keyboardType(.asciiCapable)
                        .autocorrectionDisabled()
                }

                if !statusMsg.isEmpty {
                    Section { Text(statusMsg).font(.caption).foregroundStyle(.red) }
                }

                Section {
                    Button("配对") {
                        guard !serverId.isEmpty, !userId.isEmpty, !addr.isEmpty else {
                            statusMsg = "请填写所有字段"
                            return
                        }
                        onPair(PairingCredentials(serverId: serverId, userId: userId, addr: addr))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("调试配对")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func fetchServerId() async {
        statusMsg = ""
        guard let url = URL(string: "http://\(addr)/ping") else {
            statusMsg = "无效地址"
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let ping = try JSONDecoder().decode(PingResponse.self, from: data)
            serverId = ping.serverId
        } catch {
            statusMsg = "连接失败：\(error.localizedDescription)"
        }
    }
}
#endif
