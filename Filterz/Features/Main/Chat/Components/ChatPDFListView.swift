import SwiftUI

struct ChatPDFListView: View {
    let paths: [String]
    var onPDFTapped: (String) -> Void

    var body: some View {
        VStack(spacing: 6) {
            ForEach(paths, id: \.self) { path in
                Button { onPDFTapped(path) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.filterzAccent)
                        Text((path as NSString).lastPathComponent)
                            .font(.pretendard(13, weight: .regular))
                            .foregroundColor(.filterzGray30)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.filterzGray60)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.filterzBlackAccent)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 240)
    }
}
