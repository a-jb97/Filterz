import SwiftUI
import PhotosUI

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
        var datas: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                datas.append(data)
            }
        }
        onImagesPicked(datas)
        photoSelections = []
    }
}
