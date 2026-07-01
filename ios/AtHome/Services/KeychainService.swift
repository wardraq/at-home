import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()

    private let service = "com.athome.app"
    private let pairingAccount = "pairing"
    private let sessionAccount = "session"

    private init() {}

    // MARK: - Pairing

    func savePairing(_ credentials: PairingCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        try save(data: data, account: pairingAccount)
    }

    func loadPairing() -> PairingCredentials? {
        guard let data = load(account: pairingAccount) else { return nil }
        return try? JSONDecoder().decode(PairingCredentials.self, from: data)
    }

    func deletePairing() throws {
        try delete(account: pairingAccount)
        try deleteSession()
    }

    var isPaired: Bool {
        loadPairing() != nil
    }

    // MARK: - Session

    func saveSession(_ session: SessionCredentials) throws {
        let data = try JSONEncoder().encode(session)
        try save(data: data, account: sessionAccount)
    }

    func loadSession() -> SessionCredentials? {
        guard let data = load(account: sessionAccount) else { return nil }
        guard let session = try? JSONDecoder().decode(SessionCredentials.self, from: data) else {
            return nil
        }
        if let expires = DateFormatting.parse(session.expiresAt), expires <= Date() {
            return nil
        }
        return session
    }

    func deleteSession() throws {
        try delete(account: sessionAccount)
    }

    // MARK: - Keychain primitives

    private func save(data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AtHomeError.network("Keychain 保存失败 (\(status))")
        }
    }

    private func load(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
