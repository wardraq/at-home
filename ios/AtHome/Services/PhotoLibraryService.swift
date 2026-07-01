import Foundation
import Photos

final class PhotoLibraryService {
    func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    func isAuthorized(_ status: PHAuthorizationStatus) -> Bool {
        status == .authorized || status == .limited
    }

    func fetchUserLibraryAssets() -> [PHAsset] {
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumUserLibrary,
            options: nil
        )
        guard let collection = collections.firstObject else { return [] }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let result = PHAsset.fetchAssets(in: collection, options: options)

        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    func buildUploadTask(for asset: PHAsset) throws -> UploadTask {
        guard let modDate = asset.modificationDate, let createDate = asset.creationDate else {
            throw AtHomeError.exportFailed("缺少日期信息")
        }

        let modificationDate = DateFormatting.iso8601(from: modDate)
        let creationDate = DateFormatting.iso8601(from: createDate)
        let resources = PHAssetResource.assetResources(for: asset)

        var parts: [UploadPart] = []

        if asset.mediaSubtypes.contains(.photoLive) {
            if let photo = resources.first(where: { $0.type == .photo }) {
                try appendPartIfLocal(resource: photo, kind: .image, parts: &parts)
            }
            if let video = resources.first(where: { $0.type == .pairedVideo }) {
                try appendPartIfLocal(resource: video, kind: .video, parts: &parts)
            }
        } else if asset.mediaType == .image {
            if let photo = resources.first(where: { $0.type == .photo }) ?? resources.first {
                try appendPartIfLocal(resource: photo, kind: .image, parts: &parts)
            }
        } else if asset.mediaType == .video {
            if let video = resources.first(where: { $0.type == .video }) ?? resources.first {
                try appendPartIfLocal(resource: video, kind: .video, parts: &parts)
            }
        }

        if parts.isEmpty {
            throw AtHomeError.notLocallyAvailable
        }

        return UploadTask(
            id: asset.localIdentifier,
            asset: asset,
            localIdentifier: asset.localIdentifier,
            modificationDate: modificationDate,
            creationDate: creationDate,
            parts: parts
        )
    }

    private func appendPartIfLocal(
        resource: PHAssetResource,
        kind: UploadPartKind,
        parts: inout [UploadPart]
    ) throws {
        let filename = resource.originalFilename
        parts.append(
            UploadPart(
                kind: kind,
                resource: resource,
                originalFilename: filename,
                mimeType: mimeType(for: resource, kind: kind)
            )
        )
    }

    func export(resource: PHAssetResource, to destinationURL: URL) async throws {
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = false

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(
                for: resource,
                toFile: destinationURL,
                options: options
            ) { error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == PHPhotosErrorDomain,
                       nsError.code == PHPhotosError.networkAccessRequired.rawValue {
                        continuation.resume(throwing: AtHomeError.notLocallyAvailable)
                    } else {
                        continuation.resume(throwing: AtHomeError.exportFailed(error.localizedDescription))
                    }
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func mimeType(for resource: PHAssetResource, kind: UploadPartKind) -> String {
        let ext = (resource.originalFilename as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "heic": return "image/heic"
        case "heif": return "image/heif"
        case "mov": return "video/quicktime"
        case "mp4": return "video/mp4"
        default:
            return kind == .video ? "video/quicktime" : "image/jpeg"
        }
    }
}
