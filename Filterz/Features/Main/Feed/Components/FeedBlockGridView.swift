import SwiftUI

// MARK: - FeedListView

struct FeedListView: View {
    let items: [FeedItem]
    var tagStyle: FeedListTagStyle = .filled
    var onItemTapped: (String) -> Void = { _ in }
    var onAuthorTapped: (String) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                FeedListRowView(item: item, tagStyle: tagStyle, onAuthorTapped: onAuthorTapped)
                    .onTapGesture { onItemTapped(item.id) }
            }
        }
        .padding(.horizontal, 20)
    }
}

enum FeedListTagStyle {
    case filled
    case profile
    case compactProfile
}

// MARK: - FeedListRowView

private struct FeedListRowView: View {
    let item: FeedItem
    let tagStyle: FeedListTagStyle
    let onAuthorTapped: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnailView

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.filterzDisplay(18))
                        .foregroundColor(.filterzGray30)

                    tagView
                }

                Button {
                    onAuthorTapped(item.authorId)
                } label: {
                    Text(item.authorNick)
                        .font(.pretendard(13, weight: .medium))
                        .foregroundColor(.filterzGray60)
                }
                .buttonStyle(.plain)

                Text(item.description)
                    .font(.pretendard(13, weight: .regular))
                    .foregroundColor(.filterzGray75)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var tagView: some View {
        switch tagStyle {
        case .filled:
            Text("#\(displayHashTag(item.hashtag))")
                .font(.pretendard(12, weight: .medium))
                .foregroundColor(.filterzGray60)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.filterzGray90)
                )
        case .profile:
            Text("#\(displayHashTag(item.hashtag))")
                .font(.pretendard(13, weight: .medium))
                .foregroundColor(.filterzGray30)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.filterzBlackAccent))
                .overlay(Capsule().stroke(Color.filterzDeepSprout, lineWidth: 1))
        case .compactProfile:
            Text("#\(displayHashTag(item.hashtag))")
                .font(.pretendard(9, weight: .medium))
                .foregroundColor(.filterzGray30)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.filterzBlackAccent))
                .overlay(Capsule().stroke(Color.filterzDeepSprout, lineWidth: 1))
        }
    }

    private var thumbnailView: some View {
        ZStack(alignment: .bottomTrailing) {
            AuthenticatedImageView(path: item.imageURL)
                .scaledToFill()
                .frame(width: 100, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Image(systemName: item.isLiked ? "heart.fill" : "heart")
                .resizable()
                .frame(width: 14, height: 13)
                .foregroundColor(item.isLiked ? .red : .filterzGray45)
                .padding(8)
        }
    }
}

// MARK: - FeedBlockGridView

struct FeedBlockGridView: View {
    let items: [FeedItem]
    var onItemTapped: (String) -> Void = { _ in }
    var onAuthorTapped: (String) -> Void = { _ in }

    private var columns: [[FeedMasonryItem]] {
        var columns: [[FeedMasonryItem]] = [[], []]
        var columnHeights: [CGFloat] = [0, 0]

        for (index, item) in items.enumerated() {
            let columnIndex = columnHeights[0] <= columnHeights[1] ? 0 : 1
            let masonryItem = FeedMasonryItem(item: item, index: index)
            columns[columnIndex].append(masonryItem)
            columnHeights[columnIndex] += masonryItem.estimatedHeight
        }

        return columns
    }

    private var columnWidth: CGFloat {
        let horizontalPadding: CGFloat = 40
        let columnSpacing: CGFloat = 12
        return (UIScreen.main.bounds.width - horizontalPadding - columnSpacing) / 2
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(columns.indices, id: \.self) { columnIndex in
                LazyVStack(spacing: 26) {
                    ForEach(columns[columnIndex]) { masonryItem in
                        FeedMasonryCardView(
                            masonryItem: masonryItem,
                            width: columnWidth,
                            onAuthorTapped: onAuthorTapped
                        )
                        .onTapGesture { onItemTapped(masonryItem.item.id) }
                    }
                }
                .frame(width: columnWidth)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - FeedMasonryItem

private struct FeedMasonryItem: Identifiable {
    let item: FeedItem
    let index: Int

    var id: String { item.id }

    var aspectRatio: CGFloat {
        let ratios: [CGFloat] = [0.76, 1.16, 1.28, 0.82, 1.0, 0.72, 1.1, 0.9]
        return ratios[index % ratios.count]
    }

    var estimatedHeight: CGFloat {
        1 / aspectRatio + 0.26
    }
}

// MARK: - FeedMasonryCardView

private struct FeedMasonryCardView: View {
    let masonryItem: FeedMasonryItem
    let width: CGFloat
    let onAuthorTapped: (String) -> Void

    private var item: FeedItem {
        masonryItem.item
    }

    private var isCompactCard: Bool {
        masonryItem.aspectRatio >= 1.05
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            imageCard

            Button {
                onAuthorTapped(item.authorId)
            } label: {
                Text(item.authorNick.uppercased())
                    .font(.pretendard(16, weight: .bold))
                    .foregroundColor(.filterzGray75)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.plain)
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var imageCard: some View {
        ZStack {
            AuthenticatedImageView(path: item.imageURL, contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.filterzBlackAccent)
                .clipped()

            LinearGradient(
                colors: [
                    .black.opacity(0.48),
                    .clear,
                    .black.opacity(0.56)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(width: width, height: width / masonryItem.aspectRatio)
        .overlay(alignment: .topLeading) {
            Text(item.title)
                .font(.filterzDisplay(isCompactCard ? 14 : 17))
                .foregroundColor(.filterzGray30)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(
                    maxWidth: width - (isCompactCard ? 20 : 24),
                    minHeight: isCompactCard ? 24 : 28,
                    alignment: .leading
                )
                .padding(.top, isCompactCard ? 8 : 11)
                .padding(.leading, isCompactCard ? 10 : 12)
        }
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: isCompactCard ? 13 : 15, weight: .bold))
                    .foregroundColor(.filterzGray30)

                Text("\(item.likeCount)")
                    .font(.pretendard(isCompactCard ? 14 : 16, weight: .bold))
                    .foregroundColor(.filterzGray30)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(minHeight: isCompactCard ? 22 : 24)
            .padding(.trailing, isCompactCard ? 10 : 12)
            .padding(.bottom, isCompactCard ? 8 : 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
