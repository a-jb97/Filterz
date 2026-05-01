import SwiftUI

struct ChatImageGrid: View {
    let paths: [String]

    var body: some View {
        switch paths.count {
        case 0:
            EmptyView()
        case 1:
            AuthenticatedImageView(path: paths[0], contentMode: .fit)
                .frame(maxWidth: 240, maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case 2:
            HStack(spacing: 4) {
                ForEach(paths, id: \.self) { path in
                    AuthenticatedImageView(path: path, contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        default:
            let columns = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(paths.prefix(4).enumerated()), id: \.offset) { index, path in
                    ZStack {
                        AuthenticatedImageView(path: path, contentMode: .fill)
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                        if index == 3 && paths.count > 4 {
                            Color.black.opacity(0.45)
                            Text("+\(paths.count - 4)")
                                .font(.pretendard(20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .frame(maxWidth: 244)
        }
    }
}
