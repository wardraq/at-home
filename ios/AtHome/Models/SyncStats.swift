import Foundation

struct SyncStats: Equatable {
    var phoneCount: Int = 0
    var syncedCount: Int = 0
    var pendingCount: Int = 0
    var archivedCount: Int = 0
    var skippedCount: Int = 0
    var lastSyncAt: Date?
}

struct SyncProgress: Equatable {
    var completed: Int = 0
    var total: Int = 0
    var currentLabel: String = ""
}

struct SyncSummary: Equatable {
    let uploaded: Int
    let failed: Int
    let skipped: Int
    let message: String
}
