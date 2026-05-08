import SwiftUI

struct ChatImageGrid: View {
    let paths: [String]
    var onImageTapped: (_ index: Int) -> Void = { _ in }
    var onImageLoaded: (() -> Void)? = nil

    private let spacing: CGFloat = 4
    private let cellSize: CGFloat = 120
    private let gridCornerRadius: CGFloat = 12

    var body: some View {
        switch paths.count {
        case 0:
            EmptyView()
        case 1:
            AuthenticatedImageView(path: paths[0], contentMode: .fit, onLoad: onImageLoaded)
                .frame(maxWidth: 240, maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture { onImageTapped(0) }
        case 2:
            HStack(spacing: 4) {
                ForEach(Array(paths.enumerated()), id: \.offset) { index, path in
                    AuthenticatedImageView(path: path, contentMode: .fill, onLoad: onImageLoaded)
                        .frame(width: 120, height: 120)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .contentShape(Rectangle())
                        .onTapGesture { onImageTapped(index) }
                }
            }
        default:
            let displayPaths = Array(paths.prefix(4))
            let rows = CGFloat((displayPaths.count + 1) / 2)
            let gridWidth = cellSize * 2 + spacing
            let gridHeight = cellSize * rows + spacing * max(rows - 1, 0)
            let columns = [
                GridItem(.fixed(cellSize), spacing: spacing),
                GridItem(.fixed(cellSize), spacing: spacing)
            ]

            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(Array(displayPaths.enumerated()), id: \.offset) { index, path in
                    imageCell(path: path, index: index)
                }
            }
            .frame(width: gridWidth, height: gridHeight, alignment: .topLeading)
        }
    }

    private func imageCell(path: String, index: Int) -> some View {
        ZStack {
            AuthenticatedImageView(path: path, contentMode: .fill, onLoad: onImageLoaded)
                .frame(width: cellSize, height: cellSize)
                .clipped()

            if index == 3 && paths.count > 4 {
                Color.black.opacity(0.45)
                Text("+\(paths.count - 4)")
                    .font(.pretendard(20, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .clipShape(RoundedRectangle(cornerRadius: gridCornerRadius, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { onImageTapped(index) }
    }
}
