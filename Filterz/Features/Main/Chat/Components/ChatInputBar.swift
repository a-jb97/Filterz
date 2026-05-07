import SwiftUI
import PhotosUI
import Photos
import UIKit

struct ChatInputBar: View {
    @Binding var text: String
    let pendingImages: [PickedImage]
    let isSending: Bool
    var onSend: () -> Void
    var onImagesPicked: ([PickedImage]) -> Void
    var onImageRemoved: (Int) -> Void
    var onImagePrepared: (UUID, Data, Data) -> Void

    @State private var photoSelections: [PhotosPickerItem] = []

    var body: some View {
        VStack(spacing: 0) {
            if !pendingImages.isEmpty {
                thumbnailStrip
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            }
            inputRow
        }
        .background(Color.filterzBlackBase)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: pendingImages.isEmpty)
    }

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(Array(pendingImages.enumerated()), id: \.element.id) { index, image in
                    thumbnailCell(image: image, index: index)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(height: 100)
        .background(Color.filterzBlackBase)
    }

    private func thumbnailCell(image: PickedImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            if let uiImage = UIImage(data: image.thumbnail), !image.thumbnail.isEmpty {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.filterzBlackAccent)
                    .frame(width: 80, height: 80)
            }

            if image.uploadData == nil {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 80, height: 80)
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.8)
            }

            Button { onImageRemoved(index) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.filterzBlackBase, Color.filterzGray30)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
        }
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    private var inputRow: some View {
        HStack(alignment: .center, spacing: 10) {
            PhotosPicker(
                selection: $photoSelections,
                maxSelectionCount: 5,
                matching: .images
            ) {
                Image(systemName: "photo.on.rectangle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(.filterzGray45)
            }
            .disabled(isSending)
            .onChange(of: photoSelections) { _, newValue in
                Task { await loadSelections(newValue) }
            }

            TextField("", text: $text, axis: .vertical)
                .font(.pretendard(14, weight: .regular))
                .foregroundColor(.filterzGray30)
                .lineLimit(1...4)
                .tint(.filterzAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.filterzBlackAccent)
                )

            Button(action: onSend) {
                if isSending {
                    ProgressView().tint(.filterzAccent)
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "paperplane.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundColor(canSend ? .filterzAccent : .filterzGray75)
                }
            }
            .disabled(!canSend || isSending)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.filterzBlackBase)
    }

    private var canSend: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let allReady = !pendingImages.isEmpty && pendingImages.allSatisfy { $0.uploadData != nil }
        return hasText || allReady
    }

    private func loadSelections(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        // PHAsset 맵 구성
        let identifiers = items.compactMap(\.itemIdentifier)
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assetMap: [String: PHAsset] = [:]
        fetchResult.enumerateObjects { asset, _, _ in
            assetMap[asset.localIdentifier] = asset
        }

        // Phase 1: PHImageManager 캐시에서 즉각 썸네일 로드
        var indexed: [(Int, PickedImage)] = []
        await withTaskGroup(of: (Int, PickedImage).self) { group in
            for (i, item) in items.enumerated() {
                let asset = item.itemIdentifier.flatMap { assetMap[$0] }
                group.addTask {
                    let thumbData = asset != nil
                        ? await requestFastThumbnail(asset: asset!, maxSide: 80)
                        : nil
                    return (i, PickedImage(thumbnail: thumbData ?? Data()))
                }
            }
            for await result in group {
                indexed.append(result)
            }
        }
        indexed.sort { $0.0 < $1.0 }
        let placeholders = indexed.map(\.1)

        if !placeholders.isEmpty {
            onImagesPicked(placeholders)
        }

        // Phase 2: 업로드 데이터 준비 (백그라운드, 병렬)
        // addTask 내부(백그라운드)가 아닌 for await 루프(호출자 actor = MainActor)에서 콜백 실행
        await withTaskGroup(of: (UUID, Data, Data)?.self) { group in
            for (i, item) in items.enumerated() {
                guard i < placeholders.count else { continue }
                let id = placeholders[i].id
                group.addTask {
                    guard let raw = try? await item.loadTransferable(type: Data.self),
                          let uploadData = makeChatImageUploadData(from: raw),
                          let thumbData = makeChatThumbnail(from: uploadData, maxSide: 80)
                    else { return nil }
                    return (id, uploadData, thumbData)
                }
            }
            for await result in group {
                if let (id, uploadData, thumbData) = result {
                    onImagePrepared(id, uploadData, thumbData)
                }
            }
        }

        photoSelections = []
    }
}

// PHImageManager 콜백이 여러 번 호출될 때 continuation 이중 resume 방지
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var consumed = false
    private let continuation: CheckedContinuation<Data?, Never>

    init(_ continuation: CheckedContinuation<Data?, Never>) {
        self.continuation = continuation
    }

    func resume(returning value: Data?) {
        let should: Bool = lock.withLock {
            guard !consumed else { return false }
            consumed = true
            return true
        }
        if should { continuation.resume(returning: value) }
    }
}

nonisolated private func requestFastThumbnail(asset: PHAsset, maxSide: CGFloat) async -> Data? {
    await withCheckedContinuation { continuation in
        let once = ResumeOnce(continuation)
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = false
        options.resizeMode = .fast

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: maxSide * 2, height: maxSide * 2),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            guard let image else {
                once.resume(returning: nil)
                return
            }
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            let targetSize = CGSize(width: maxSide, height: maxSide)
            let thumb = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            once.resume(returning: thumb.jpegData(compressionQuality: 0.75))
        }
    }
}

nonisolated private func makeChatImageUploadData(from data: Data) -> Data? {
    let limit = 2 * 1024 * 1024
    let maxSide: CGFloat = 1920

    guard let image = UIImage(data: data) else { return nil }

    let scale = min(maxSide / image.size.width, maxSide / image.size.height, 1.0)
    let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let renderImage: UIImage

    if scale < 1.0 {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        renderImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    } else {
        renderImage = image
    }

    for quality: CGFloat in [0.85, 0.7, 0.55, 0.4, 0.25, 0.1] {
        if let compressed = renderImage.jpegData(compressionQuality: quality),
           compressed.count <= limit {
            return compressed
        }
    }

    return renderImage.jpegData(compressionQuality: 0.1)
}

nonisolated private func makeChatThumbnail(from data: Data, maxSide: CGFloat) -> Data? {
    guard let image = UIImage(data: data) else { return nil }
    let side = max(image.size.width, image.size.height)
    let scale = min(maxSide / side, 1.0)
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
        image.draw(in: CGRect(origin: .zero, size: size))
    }
    return resized.jpegData(compressionQuality: 0.75)
}
