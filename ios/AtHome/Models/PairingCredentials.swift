import Foundation

struct PairingCredentials: Codable, Equatable {
    let serverId: String
    let userId: String
    let addr: String

    init(serverId: String, userId: String, addr: String) {
        self.serverId = serverId
        self.userId = userId
        self.addr = addr
    }

    init?(qrPayload: [String: Any]) {
        guard
            let serverId = qrPayload["serverId"] as? String,
            let userId = qrPayload["userId"] as? String,
            let addr = qrPayload["addr"] as? String,
            !serverId.isEmpty, !userId.isEmpty, !addr.isEmpty
        else { return nil }
        self.serverId = serverId
        self.userId = userId
        self.addr = addr
    }

    init?(jsonData: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }
        self.init(qrPayload: object)
    }
}

struct SessionCredentials: Codable, Equatable {
    let sessionToken: String
    let expiresAt: String
    let userName: String
}

enum AtHomeError: LocalizedError {
    case notPaired
    case serverIdentityMismatch
    case invalidQRCode
    case photoAccessDenied
    case network(String)
    case api(code: String, message: String)
    case exportFailed(String)
    case notLocallyAvailable

    var errorDescription: String? {
        switch self {
        case .notPaired: return "尚未配对，请先扫描二维码"
        case .serverIdentityMismatch: return "服务器身份不匹配，可能是连错了接收端"
        case .invalidQRCode: return "无效的配对二维码"
        case .photoAccessDenied: return "需要相册访问权限才能同步照片"
        case .network(let msg): return msg
        case .api(_, let message): return message
        case .exportFailed(let msg): return "导出照片失败：\(msg)"
        case .notLocallyAvailable: return "照片未下载到本机"
        }
    }
}
