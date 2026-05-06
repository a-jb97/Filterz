import SwiftUI
import PhotosUI
import UIKit

struct ChatInputBar: View {
    @Binding var text: String
    let pickedImageCount: Int
    let isSending: Bool
    var onSend: () -> Void
    var onImagesPicked: ([Data]) -> Void

    @State private var photoSelections: [PhotosPickerItem] = []

    var body: some View {
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

            HStack(spacing: 8) {
                TextField("", text: $text, axis: .vertical)
                    .font(.pretendard(14, weight: .regular))
                    .foregroundColor(.filterzGray30)
                    .lineLimit(1...4)
                    .tint(.filterzAccent)

                if pickedImageCount > 0 {
                    Text("\(pickedImageCount)")
                        .font(.pretendard(12, weight: .semibold))
                        .foregroundColor(.filterzBlackBase)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.filterzAccent))
                }
            }
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
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pickedImageCount > 0
    }

    private func loadSelections(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        var datas: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let jpegData = makeChatImageUploadData(from: data) {
                datas.append(jpegData)
            }
        }
        if !datas.isEmpty {
            onImagesPicked(datas)
        }
        photoSelections = []
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
