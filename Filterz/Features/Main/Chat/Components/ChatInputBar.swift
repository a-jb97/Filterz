import SwiftUI
import PhotosUI
import Photos
import UIKit
import UniformTypeIdentifiers

struct ChatInputBar: View {
    @Binding var text: String
    let pendingImages: [PickedImage]
    let pendingFiles: [PickedFile]
    let isSending: Bool
    var onSend: () -> Void
    var onImagesPicked: ([PickedImage]) -> Void
    var onImageRemoved: (Int) -> Void
    var onImagePrepared: (UUID, Data, Data) -> Void
    var onFilesPicked: ([PickedFile]) -> Void
    var onFileRemoved: (Int) -> Void
    var onInvalidAttachment: (String) -> Void

    @State private var photoSelections: [PhotosPickerItem] = []
    @State private var showFilePicker = false

    private let maxAttachments = 5
    private var totalAttachments: Int { pendingImages.count + pendingFiles.count }
    private var hasAttachments: Bool { !pendingImages.isEmpty || !pendingFiles.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            if hasAttachments {
                thumbnailStrip
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            }
            inputRow
        }
        .background(Color.filterzBlackBase)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: hasAttachments)
    }

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(Array(pendingImages.enumerated()), id: \.element.id) { index, image in
                    thumbnailCell(image: image, index: index)
                }
                ForEach(Array(pendingFiles.enumerated()), id: \.element.id) { index, file in
                    pdfCell(file: file, index: index)
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

    private func pdfCell(file: PickedFile, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.filterzBlackAccent)
            VStack(spacing: 4) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.filterzAccent)
                Text(file.name)
                    .font(.pretendard(10, weight: .regular))
                    .foregroundColor(.filterzGray45)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .truncationMode(.middle)
                    .padding(.horizontal, 6)
            }
            .frame(width: 80, height: 80)
            Button { onFileRemoved(index) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.filterzBlackBase, Color.filterzGray30)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    private var inputRow: some View {
        HStack(alignment: .center, spacing: 10) {
            PhotosPicker(
                selection: $photoSelections,
                maxSelectionCount: max(1, maxAttachments - pendingFiles.count),
                matching: .images
            ) {
                Image(systemName: "photo.on.rectangle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(.filterzGray45)
            }
            .disabled(isSending || totalAttachments >= maxAttachments)
            .onChange(of: photoSelections) { _, newValue in
                Task { await loadSelections(newValue) }
            }

            Button { showFilePicker = true } label: {
                Image(systemName: "paperclip")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(.filterzGray45)
            }
            .disabled(isSending || totalAttachments >= maxAttachments)
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: true
            ) { result in
                Task { await handleFilePicker(result) }
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
        let allImagesReady = pendingImages.allSatisfy { $0.uploadData != nil }
        let hasAttachment = (!pendingImages.isEmpty && allImagesReady) || !pendingFiles.isEmpty
        return hasText || hasAttachment
    }

    private func handleFilePicker(_ result: Result<[URL], any Error>) async {
        guard case .success(let urls) = result else { return }
        var picked: [PickedFile] = []
        var rejected: [String] = []

        for url in urls {
            let ext = url.pathExtension.lowercased()
            guard ext == "pdf" else {
                rejected.append(url.lastPathComponent)
                continue
            }
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            if let data = try? Data(contentsOf: url) {
                picked.append(PickedFile(name: url.lastPathComponent, data: data))
            }
        }

        let fileLimit = maxAttachments - pendingImages.count
        let allowedFiles = Array(picked.prefix(max(0, fileLimit)))
        if !allowedFiles.isEmpty { onFilesPicked(allowedFiles) }
        if picked.count > allowedFiles.count {
            onInvalidAttachment("사진과 파일을 합쳐 최대 \(maxAttachments)개까지 첨부할 수 있습니다.")
        } else if !rejected.isEmpty {
            onInvalidAttachment("첨부할 수 없는 파일 형식입니다: \(rejected.joined(separator: ", "))\n(PDF 파일만 첨부 가능합니다)")
        }
    }

    private func loadSelections(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        let identifiers = items.compactMap(\.itemIdentifier)
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assetMap: [String: PHAsset] = [:]
        fetchResult.enumerateObjects { asset, _, _ in
            assetMap[asset.localIdentifier] = asset
        }

        let allowedPhotoTypes: Set<String> = [
            UTType.jpeg.identifier,
            UTType.png.identifier,
            UTType.gif.identifier
        ]

        // Phase 1: PHImageManager 캐시에서 즉각 썸네일 로드 (허용된 형식만)
        var indexed: [(Int, PickedImage)] = []
        var rejectedCount = 0
        await withTaskGroup(of: (Int, PickedImage?).self) { group in
            for (i, item) in items.enumerated() {
                let asset = item.itemIdentifier.flatMap { assetMap[$0] }
                group.addTask {
                    guard let asset else { return (i, PickedImage(thumbnail: Data())) }
                    let typeID = PHAssetResource.assetResources(for: asset).first?.uniformTypeIdentifier ?? ""
                    guard allowedPhotoTypes.contains(typeID) else { return (i, nil) }
                    let thumbData = await requestFastThumbnail(asset: asset, maxSide: 80)
                    return (i, PickedImage(thumbnail: thumbData ?? Data()))
                }
            }
            for await (i, pickedImage) in group {
                if let pickedImage {
                    indexed.append((i, pickedImage))
                } else {
                    rejectedCount += 1
                }
            }
        }
        indexed.sort { $0.0 < $1.0 }
        let imageLimit = maxAttachments - pendingFiles.count
        let clampedIndexed = Array(indexed.prefix(max(0, imageLimit)))
        let trimmedCount = indexed.count - clampedIndexed.count
        let placeholders = clampedIndexed.map(\.1)

        if !placeholders.isEmpty {
            onImagesPicked(placeholders)
        }
        if trimmedCount > 0 {
            onInvalidAttachment("사진과 파일을 합쳐 최대 \(maxAttachments)개까지 첨부할 수 있습니다.")
        } else if rejectedCount > 0 {
            onInvalidAttachment("지원하지 않는 사진 형식이 포함되어 있습니다.\n(jpg, jpeg, png, gif만 첨부 가능합니다)")
        }

        // Phase 2: 업로드 데이터 준비 (백그라운드, 병렬)
        // for await 루프(MainActor)에서 콜백 실행 — @MainActor 위반 방지
        let validItems: [(Int, PhotosPickerItem)] = clampedIndexed.map(\.0).enumerated().compactMap { seqIdx, originalIdx in
            guard originalIdx < items.count else { return nil }
            return (seqIdx, items[originalIdx])
        }
        await withTaskGroup(of: (UUID, Data, Data)?.self) { group in
            for (seqIdx, item) in validItems {
                guard seqIdx < placeholders.count else { continue }
                let id = placeholders[seqIdx].id
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

    let qualityRaw = UserDefaults.standard.string(forKey: ImageQualityOption.defaultsKey) ?? ""
    let quality = ImageQualityOption(rawValue: qualityRaw) ?? .original

    guard let image = UIImage(data: data) else { return nil }

    let pixelWidth = image.size.width * image.scale
    let pixelHeight = image.size.height * image.scale
    let pixelScale = min(maxSide / pixelWidth, maxSide / pixelHeight, 1.0)

    let renderImage: UIImage
    if pixelScale < 1.0 {
        let targetPixels = CGSize(width: pixelWidth * pixelScale, height: pixelHeight * pixelScale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        renderImage = UIGraphicsImageRenderer(size: targetPixels, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetPixels))
        }
    } else {
        renderImage = image
    }

    switch quality {
    case .original:
        for q: CGFloat in [1.0, 0.85, 0.7, 0.55, 0.4, 0.25, 0.1] {
            if let compressed = renderImage.jpegData(compressionQuality: q),
               compressed.count <= limit {
                return compressed
            }
        }
        return renderImage.jpegData(compressionQuality: 0.1)

    case .high:
        if let compressed = renderImage.jpegData(compressionQuality: 0.7),
           compressed.count <= limit {
            return compressed
        }
        for q: CGFloat in [0.55, 0.4, 0.25, 0.1] {
            if let compressed = renderImage.jpegData(compressionQuality: q),
               compressed.count <= limit {
                return compressed
            }
        }
        return renderImage.jpegData(compressionQuality: 0.1)

    case .low:
        if let compressed = renderImage.jpegData(compressionQuality: 0.4),
           compressed.count <= limit {
            return compressed
        }
        for q: CGFloat in [0.25, 0.1] {
            if let compressed = renderImage.jpegData(compressionQuality: q),
               compressed.count <= limit {
                return compressed
            }
        }
        return renderImage.jpegData(compressionQuality: 0.1)
    }
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
