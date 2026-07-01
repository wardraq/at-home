import Foundation
import Photos

enum UploadPartKind: String {
    case image
    case video
}

struct UploadPart: Identifiable {
    let id = UUID()
    let kind: UploadPartKind
    let resource: PHAssetResource
    let originalFilename: String
    let mimeType: String
}

struct UploadTask: Identifiable {
    let id: String
    let asset: PHAsset
    let localIdentifier: String
    let modificationDate: String
    let creationDate: String
    let parts: [UploadPart]

    var creationDateValue: Date {
        asset.creationDate ?? .distantPast
    }
}
