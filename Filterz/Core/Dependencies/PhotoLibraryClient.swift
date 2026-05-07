import ComposableArchitecture
import Foundation
import Photos
import UIKit

struct PhotoLibraryClient: Sendable {
    var saveImageData: @Sendable (_ imageData: Data) async throws -> Void
}

extension PhotoLibraryClient: DependencyKey {
    static var liveValue: PhotoLibraryClient {
        PhotoLibraryClient(
            saveImageData: { imageData in
                try await saveToPhotoLibrary(imageData)
            }
        )
    }

    static var testValue: PhotoLibraryClient {
        PhotoLibraryClient(saveImageData: { _ in })
    }
}

extension DependencyValues {
    var photoLibraryClient: PhotoLibraryClient {
        get { self[PhotoLibraryClient.self] }
        set { self[PhotoLibraryClient.self] = newValue }
    }
}

private enum PhotoLibrarySaveError: LocalizedError {
    case invalidImageData
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "저장할 이미지를 만들 수 없습니다."
        case .unauthorized:
            return "사진앱 저장 권한이 필요합니다."
        }
    }
}

private func saveToPhotoLibrary(_ imageData: Data) async throws {
    guard UIImage(data: imageData) != nil else {
        throw PhotoLibrarySaveError.invalidImageData
    }

    let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    guard status == .authorized || status == .limited else {
        throw PhotoLibrarySaveError.unauthorized
    }

    try await PHPhotoLibrary.shared().performChanges {
        let request = PHAssetCreationRequest.forAsset()
        request.addResource(with: .photo, data: imageData, options: nil)
    }
}
