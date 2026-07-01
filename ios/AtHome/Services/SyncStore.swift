import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct SyncedPhotoRecord {
    let localIdentifier: String
    let modificationDate: String
    let syncedAt: String
}

final class SyncStore {
    private var db: OpaquePointer?

    init() throws {
        let url = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("AtHome", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let dbURL = url.appendingPathComponent("sync.sqlite")
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            throw AtHomeError.network("无法打开同步数据库")
        }
        try execute("""
            CREATE TABLE IF NOT EXISTS synced_photos (
                local_identifier TEXT PRIMARY KEY,
                modification_date TEXT NOT NULL,
                synced_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_synced_mod ON synced_photos(modification_date);
            """)
    }

    deinit {
        sqlite3_close(db)
    }

    func markSynced(localIdentifier: String, modificationDate: String) throws {
        let now = DateFormatting.iso8601(from: Date())
        try execute(
            """
            INSERT INTO synced_photos (local_identifier, modification_date, synced_at)
            VALUES (?, ?, ?)
            ON CONFLICT(local_identifier) DO UPDATE SET
                modification_date = excluded.modification_date,
                synced_at = excluded.synced_at;
            """,
            bind: [localIdentifier, modificationDate, now]
        )
    }

    func clearAll() throws {
        try execute("DELETE FROM synced_photos;")
    }

    func allRecords() throws -> [SyncedPhotoRecord] {
        try query("SELECT local_identifier, modification_date, synced_at FROM synced_photos;")
    }

    func syncedMap() throws -> [String: String] {
        let records = try allRecords()
        return Dictionary(uniqueKeysWithValues: records.map { ($0.localIdentifier, $0.modificationDate) })
    }

    func lastSyncDate() throws -> Date? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT MAX(synced_at) FROM synced_photos;", -1, &statement, nil) == SQLITE_OK else {
            throw dbError()
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        guard sqlite3_column_type(statement, 0) != SQLITE_NULL else { return nil }
        let value = stringColumn(statement, 0)
        return DateFormatting.parse(value)
    }

    func needsUpload(localIdentifier: String, modificationDate: String, syncedMap: [String: String]) -> Bool {
        guard let stored = syncedMap[localIdentifier] else { return true }
        return stored != modificationDate
    }

    func computeStats(
        phoneIdentifiers: Set<String>,
        identifierDates: [String: String],
        syncedMap: [String: String]
    ) -> SyncStats {
        let syncedIDs = Set(syncedMap.keys)
        let phoneIDs = phoneIdentifiers

        var pending = 0
        var synced = 0

        for id in phoneIDs {
            let mod = identifierDates[id] ?? ""
            if needsUpload(localIdentifier: id, modificationDate: mod, syncedMap: syncedMap) {
                pending += 1
            } else {
                synced += 1
            }
        }

        let archived = syncedIDs.subtracting(phoneIDs).count

        return SyncStats(
            phoneCount: phoneIDs.count,
            syncedCount: synced,
            pendingCount: pending,
            archivedCount: archived,
            skippedCount: 0,
            lastSyncAt: nil
        )
    }

    // MARK: - SQLite helpers

    private func execute(_ sql: String, bind values: [String] = []) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw dbError()
        }
        defer { sqlite3_finalize(statement) }
        for (index, value) in values.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), value, -1, SQLITE_TRANSIENT)
        }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw dbError()
        }
    }

    private func query(_ sql: String) throws -> [SyncedPhotoRecord] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw dbError()
        }
        defer { sqlite3_finalize(statement) }

        var rows: [SyncedPhotoRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = stringColumn(statement, 0)
            let mod = stringColumn(statement, 1)
            let synced = stringColumn(statement, 2)
            rows.append(SyncedPhotoRecord(localIdentifier: id, modificationDate: mod, syncedAt: synced))
        }
        return rows
    }

    private func stringColumn(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let cString = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: cString)
    }

    private func dbError() -> AtHomeError {
        let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
        return .network("数据库错误：\(message)")
    }
}
