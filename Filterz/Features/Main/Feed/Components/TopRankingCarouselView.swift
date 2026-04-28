import SwiftUI

struct TopRankingCarouselView: View {
    let items: [FeedItem]
    var onItemTapped: (String) -> Void = { _ in }

    @State private var focusedID: String?

    private let cardWidth: CGFloat = 220
    private let liftAmount: CGFloat = 100

    var body: some View {
        GeometryReader { geo in
            let sidePad = max(0, (geo.size.width - cardWidth) / 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { pair in
                        RankingCardView(item: pair.element, rank: pair.offset + 1)
                            .id(pair.element.id)
                            .scrollTransition(.interactive) { content, phase in
                                let lift = liftAmount * (1 - abs(phase.value))
                                return content.offset(y: -lift)
                            }
                            .onTapGesture { onItemTapped(pair.element.id) }
                    }
                }
                .scrollTargetLayout()
                .padding(.top, liftAmount)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focusedID)
            .contentMargins(.horizontal, sidePad, for: .scrollContent)
            .scrollClipDisabled()
        }
        .frame(height: 510)
        .onChange(of: items) { _, newItems in
            guard focusedID == nil, let first = newItems.first else { return }
            focusedID = first.id
        }
    }
}

// MARK: - RankingCardView

private struct RankingCardView: View {
    let item: FeedItem
    let rank: Int

    private let cardHeight: CGFloat = 380
    private let badgeRadius: CGFloat = 22

    var body: some View {
        ZStack(alignment: .bottom) {
            card
                .padding(.bottom, badgeRadius)

            RankBadgeView(rank: rank)
        }
        .frame(width: 220, height: cardHeight + badgeRadius)
    }

    private var card: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 110, style: .circular)
                .fill(Color.filterzBlackTurquoise)
                .overlay(
                    RoundedRectangle(cornerRadius: 110, style: .circular)
                        .stroke(Color.filterzDeepSprout, lineWidth: 2)
                )

            VStack(spacing: 6) {
                Text(item.authorNick.uppercased())
                    .font(.pretendard(12, weight: .semibold))
                    .foregroundColor(.filterzGray75)

                Text(item.title)
                    .font(.filterzDisplay(28))
                    .foregroundColor(.filterzGray30)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                Text("#\(item.hashtag)")
                    .font(.pretendard(14, weight: .bold))
                    .foregroundColor(.filterzGray75)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .frame(width: 220, height: cardHeight)
        .overlay(alignment: .top) {
            AuthenticatedImageView(path: item.imageURL)
                .frame(width: 190, height: 190)
                .clipped()
                .clipShape(Circle())
                .padding(.top, 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 110, style: .circular))
    }
}

// MARK: - RankBadgeView

private struct RankBadgeView: View {
    let rank: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.filterzBlackTurquoise)
                .overlay(
                    Circle()
                        .stroke(Color.filterzDeepSprout, lineWidth: 2)
                )
                .frame(width: 44, height: 44)

            Text("\(rank)")
                .font(.filterzDisplay(24))
                .foregroundColor(.filterzBrightTurquoise)
        }
    }
}
