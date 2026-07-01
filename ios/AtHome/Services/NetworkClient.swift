import Foundation
import UIKit

struct PingResponse: Decodable {
    let status: String
    let serverId: String
    let version: String
}

struct HandshakeResponse: Decodable {
    let status: String
    let serverId: String
    let sessionToken: String
    let userName: String
    let expiresAt: String
}

struct UploadResponse: Decodable {
    let status: String
    let localIdentifier: String
    let version: Int
    let part: String
    let path: String
    let uploadedAt: String
}

struct APIErrorBody: Decodable {
    let status: String
    let code: String?
    let message: String?
}

final class NetworkClient {
    private let keychain = KeychainService.shared
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    private func baseURL() throws -> URL {
        guard let pairing = keychain.loadPairing() else { throw AtHomeError.notPaired }
        guard let url = URL(string: "http://\(pairing.addr)") else {
            throw AtHomeError.network("无效的服务器地址")
        }
        return url
    }

    // MARK: - Ping

    func ping() async throws -> PingResponse {
        let url = try baseURL().appendingPathComponent("ping")
        let (data, response) = try await urlSession.data(from: url)
        try validateHTTP(response)
        return try decode(data, as: PingResponse.self)
    }

    // MARK: - Handshake

    @discardableResult
    func handshake() async throws -> SessionCredentials {
        guard let pairing = keychain.loadPairing() else { throw AtHomeError.notPaired }

        let url = try baseURL().appendingPathComponent("handshake")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "userId": pairing.userId,
            "deviceName": UIDevice.current.name,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)
        try validateHTTP(response, data: data)

        let decoded = try decode(data, as: HandshakeResponse.self)
        guard decoded.serverId == pairing.serverId else {
            throw AtHomeError.serverIdentityMismatch
        }

        let session = SessionCredentials(
            sessionToken: decoded.sessionToken,
            expiresAt: decoded.expiresAt,
            userName: decoded.userName
        )
        try keychain.saveSession(session)
        return session
    }

    func testConnection() async throws -> String {
        let ping = try await ping()
        guard let pairing = keychain.loadPairing(), ping.serverId == pairing.serverId else {
            throw AtHomeError.serverIdentityMismatch
        }
        let session = try await handshake()
        return session.userName
    }

    // MARK: - Upload

    func upload(
        fileURL: URL,
        localIdentifier: String,
        modificationDate: String,
        creationDate: String,
        part: UploadPartKind,
        originalFilename: String,
        mimeType: String
    ) async throws -> UploadResponse {
        try await uploadWithRetry(
            fileURL: fileURL,
            localIdentifier: localIdentifier,
            modificationDate: modificationDate,
            creationDate: creationDate,
            part: part,
            originalFilename: originalFilename,
            mimeType: mimeType,
            allowRetry: true
        )
    }

    private func uploadWithRetry(
        fileURL: URL,
        localIdentifier: String,
        modificationDate: String,
        creationDate: String,
        part: UploadPartKind,
        originalFilename: String,
        mimeType: String,
        allowRetry: Bool
    ) async throws -> UploadResponse {
        do {
            return try await performUpload(
                fileURL: fileURL,
                localIdentifier: localIdentifier,
                modificationDate: modificationDate,
                creationDate: creationDate,
                part: part,
                originalFilename: originalFilename,
                mimeType: mimeType
            )
        } catch let error as AtHomeError {
            if case .api(let code, _) = error, code == "TOKEN_EXPIRED", allowRetry {
                try keychain.deleteSession()
                _ = try await handshake()
                return try await uploadWithRetry(
                    fileURL: fileURL,
                    localIdentifier: localIdentifier,
                    modificationDate: modificationDate,
                    creationDate: creationDate,
                    part: part,
                    originalFilename: originalFilename,
                    mimeType: mimeType,
                    allowRetry: false
                )
            }
            throw error
        }
    }

    private func performUpload(
        fileURL: URL,
        localIdentifier: String,
        modificationDate: String,
        creationDate: String,
        part: UploadPartKind,
        originalFilename: String,
        mimeType: String
    ) async throws -> UploadResponse {
        var session = keychain.loadSession()
        if session == nil {
            session = try await handshake()
        }
        guard let token = session?.sessionToken else {
            throw AtHomeError.network("无法获取 sessionToken")
        }

        let url = try baseURL().appendingPathComponent("upload")
        let boundary = "AtHome-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let fileData = try Data(contentsOf: fileURL)
        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append(value.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }

        appendField("localIdentifier", localIdentifier)
        appendField("modificationDate", modificationDate)
        appendField("creationDate", creationDate)
        appendField("part", part.rawValue)
        appendField("originalFilename", originalFilename)
        appendField("mimeType", mimeType)

        let filename = originalFilename.isEmpty ? "upload.bin" : originalFilename
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!
        )
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let (data, response) = try await urlSession.upload(for: request, from: body)
        try validateHTTP(response, data: data)
        return try decode(data, as: UploadResponse.self)
    }

    // MARK: - Helpers

    private func validateHTTP(_ response: URLResponse, data: Data? = nil) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AtHomeError.network("无效响应")
        }
        guard (200 ... 299).contains(http.statusCode) else {
            if let data, let apiError = try? JSONDecoder().decode(APIErrorBody.self, from: data) {
                throw AtHomeError.api(
                    code: apiError.code ?? "HTTP_\(http.statusCode)",
                    message: apiError.message ?? "请求失败"
                )
            }
            throw AtHomeError.network("HTTP \(http.statusCode)")
        }
    }

    private func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AtHomeError.network("解析响应失败")
        }
    }
}
