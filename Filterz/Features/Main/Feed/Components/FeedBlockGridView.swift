import SwiftUI

// MARK: - FeedListView

struct FeedListView: View {
    let items: [FeedItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                FeedListRowView(item: item)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - FeedListRowView

private struct FeedListRowView: View {
    let item: FeedItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnailView

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.filterzDisplay(18))
                        .foregroundColor(.filterzGray30)

                    Text("#\(item.hashtag)")
                        .font(.pretendard(12, weight: .medium))
                        .foregroundColor(.filterzGray60)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color.filterzGray90)
                        )
                }

                Text(item.authorNick)
                    .font(.pretendard(13, weight: .medium))
                    .foregroundColor(.filterzGray60)

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

    private var leftItems: [FeedItem] {
        items.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)
    }

    private var rightItems: [FeedItem] {
        items.enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 8) {
                ForEach(leftItems) { item in
                    FeedMasonryCardView(item: item)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                ForEach(rightItems) { item in
                    FeedMasonryCardView(item: item)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - FeedMasonryCardView

private struct FeedMasonryCardView: View {
    let item: FeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                AuthenticatedImageView(path: item.imageURL, contentMode: .fit)
                    .frame(maxWidth: .infinity)

                VStack {
                    HStack {
                        Text(item.title)
                            .font(.filterzDisplay(14))
                            .foregroundColor(.filterzGray30)
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill")
                                .resizable()
                                .frame(width: 12, height: 11)
                                .foregroundColor(.filterzGray30)
                            Text("\(item.likeCount)")
                                .font(.pretendard(12, weight: .semibold))
                                .foregroundColor(.filterzGray30)
                        }
                    }
                }
                .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(item.authorNick)
                .font(.pretendard(12, weight: .medium))
                .foregroundColor(.filterzGray75)
                .padding(.horizontal, 4)
        }
    }
}
