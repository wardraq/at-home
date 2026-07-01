import Foundation
import Observation

@Observable
final class AppModel {
    var isPaired: Bool
    var userName: String?
    var pairing: PairingCredentials?
    var statusMessage: String?

    let syncEngine: SyncEngine

    private let keychain = KeychainService.shared
    private let network = NetworkClient()

    init() {
        let store: SyncStore
        do {
            store = try SyncStore()
        } catch {
            fatalError("无法初始化数据库: \(error)")
        }

        // DEBUG: 自动配对本地服务器（模拟器无法扫码）
        #if DEBUG
        if KeychainService.shared.loadPairing() == nil {
            let creds = PairingCredentials(
                serverId: "srv-B515C08A6D84",
                userId: "usr-d59653df12a70f80",
                addr: "127.0.0.1:6060"
            )
            try? KeychainService.shared.savePairing(creds)
        }
        #endif

        let loadedPairing = KeychainService.shared.loadPairing()
        let session = KeychainService.shared.loadSession()
        self.syncEngine = SyncEngine(store: store)
        self.pairing = loadedPairing
        self.isPaired = loadedPairing != nil && session != nil
        self.userName = session?.userName
        self.statusMessage = nil
    }

    func applyPairing(_ credentials: PairingCredentials) throws {
        try keychain.savePairing(credentials)
        try keychain.deleteSession()
        pairing = credentials
        isPaired = false
        userName = nil
    }

    func testConnection() async throws -> String {
        let name = try await network.testConnection()
        userName = name
        isPaired = true
        statusMessage = "连接成功：\(name)"
        return name
    }

    func unpair() throws {
        try keychain.deletePairing()
        try syncEngine.clearSyncRecords()
        pairing = nil
        isPaired = false
        userName = nil
    }

    func clearSyncRecords() throws {
        try syncEngine.clearSyncRecords()
    }
}
