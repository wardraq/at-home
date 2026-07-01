import Foundation
import Observation
import Photos

@Observable
final class SyncEngine {
    private(set) var stats = SyncStats()
    private(set) var progress = SyncProgress()
    private(set) var isSyncing = false
    private(set) var lastSummary: SyncSummary?

    private let network = NetworkClient()
    private let photos = PhotoLibraryService()
    private let store: SyncStore

    init(store: SyncStore) {
        self.store = store
    }

    func refreshStats() async {
        let status = await photos.requestAuthorization()
        guard photos.isAuthorized(status) else {
            stats = SyncStats()
            return
        }

        let assets = photos.fetchUserLibraryAssets()
        let phoneIDs = Set(assets.map(\.localIdentifier))
        var dates: [String: String] = [:]
        for asset in assets {
            if let mod = asset.modificationDate {
                dates[asset.localIdentifier] = DateFormatting.iso8601(from: mod)
            }
        }

        do {
            let syncedMap = try store.syncedMap()
            var computed = store.computeStats(
                phoneIdentifiers: phoneIDs,
                identifierDates: dates,
                syncedMap: syncedMap
            )
            computed.lastSyncAt = try store.lastSyncDate()
            stats = computed
        } catch {
            stats = SyncStats(phoneCount: phoneIDs.count)
        }
    }

    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        lastSummary = nil
        defer { isSyncing = false }

        var uploaded = 0
        var failed = 0
        var skipped = 0

        do {
            let status = await photos.requestAuthorization()
            guard photos.isAuthorized(status) else {
                throw AtHomeError.photoAccessDenied
            }

            _ = try await network.ping()
            _ = try await network.handshake()

            let assets = photos.fetchUserLibraryAssets()
            let syncedMap = try store.syncedMap()

            var pendingTasks: [UploadTask] = []
            for asset in assets {
                guard let modDate = asset.modificationDate else { continue }
                let mod = DateFormatting.iso8601(from: modDate)
                guard store.needsUpload(
                    localIdentifier: asset.localIdentifier,
                    modificationDate: mod,
                    syncedMap: syncedMap
                ) else { continue }

                do {
                    let task = try photos.buildUploadTask(for: asset)
                    pendingTasks.append(task)
                } catch AtHomeError.notLocallyAvailable {
                    skipped += 1
                } catch {
                    failed += 1
                }
            }

            pendingTasks.sort { $0.creationDateValue < $1.creationDateValue }
            progress = SyncProgress(completed: 0, total: pendingTasks.count, currentLabel: "")

            for (index, task) in pendingTasks.enumerated() {
                progress = SyncProgress(
                    completed: index,
                    total: pendingTasks.count,
                    currentLabel: task.localIdentifier
                )

                do {
                    try await uploadTask(task)
                    try store.markSynced(
                        localIdentifier: task.localIdentifier,
                        modificationDate: task.modificationDate
                    )
                    uploaded += 1
                } catch AtHomeError.notLocallyAvailable {
                    skipped += 1
                } catch {
                    failed += 1
                }

                progress.completed = index + 1
            }

            let message: String
            if failed == 0 && skipped == 0 {
                message = "同步完成，上传 \(uploaded) 项"
            } else {
                message = "完成：成功 \(uploaded)，失败 \(failed)，跳过 \(skipped)"
            }
            lastSummary = SyncSummary(uploaded: uploaded, failed: failed, skipped: skipped, message: message)
        } catch {
            lastSummary = SyncSummary(uploaded: uploaded, failed: failed + 1, skipped: skipped, message: error.localizedDescription)
        }

        progress = SyncProgress()
        await refreshStats()
    }

    private func uploadTask(_ task: UploadTask) async throws {
        for part in task.parts {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension((part.originalFilename as NSString).pathExtension)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            try await photos.export(resource: part.resource, to: tempURL)
            _ = try await network.upload(
                fileURL: tempURL,
                localIdentifier: task.localIdentifier,
                modificationDate: task.modificationDate,
                creationDate: task.creationDate,
                part: part.kind,
                originalFilename: part.originalFilename,
                mimeType: part.mimeType
            )
        }
    }

    func clearSyncRecords() throws {
        try store.clearAll()
    }
}
