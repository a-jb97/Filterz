import SwiftUI

struct TopRankingCarouselView: View {
    let items: [FeedItem]
    var onItemTapped: (String) -> Void = { _ in }
    var onAuthorTapped: (String) -> Void = { _ in }

    @State private var focusedID: String?
    @State private var swayTrigger = 0
    @State private var swayDirection: Double = 1

    private let cardWidth: CGFloat = 260
    private let itemSpacing: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let sidePad = max(0, (geo.size.width - cardWidth) / 2)

            ZStack(alignment: .top) {
                clothesline
                    .padding(.top, 17)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: itemSpacing) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { pair in
                            HangingRankingCardView(
                                item: pair.element,
                                rank: pair.offset + 1,
                                swayTrigger: swayTrigger,
                                swayDirection: swayDirection,
                                onAuthorTapped: onAuthorTapped
                            )
                                .id(pair.element.id)
                                .onTapGesture { onItemTapped(pair.element.id) }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $focusedID)
                .contentMargins(.horizontal, sidePad, for: .scrollContent)
                .scrollClipDisabled()
            }
        }
        .frame(height: 430)
        .onChange(of: items) { _, newItems in
            guard focusedID == nil, let first = newItems.first else { return }
            focusedID = first.id
        }
        .onChange(of: focusedID) { oldValue, newValue in
            guard
                let oldValue,
                let newValue,
                oldValue != newValue,
                let oldIndex = items.firstIndex(where: { $0.id == oldValue }),
                let newIndex = items.firstIndex(where: { $0.id == newValue })
            else { return }

            swayDirection = newIndex > oldIndex ? -1 : 1
            swayTrigger += 1
        }
    }

    private var clothesline: some View {
        Rectangle()
            .fill(Color.filterzAccent.opacity(0.56))
            .frame(height: 1.3)
            .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
            .allowsHitTesting(false)
    }
}

// MARK: - HangingRankingCardView

private struct HangingRankingCardView: View {
    let item: FeedItem
    let rank: Int
    let swayTrigger: Int
    let swayDirection: Double
    let onAuthorTapped: (String) -> Void

    private let cardWidth: CGFloat = 260
    private let hangingHeight: CGFloat = 30

    var body: some View {
        ZStack(alignment: .top) {
            RankingCardView(
                item: item,
                rank: rank,
                onAuthorTapped: onAuthorTapped
            )
            .padding(.top, hangingHeight)

            ClothespinView()
                .padding(.top, 3)
        }
        .frame(width: cardWidth, height: 404, alignment: .top)
        .keyframeAnimator(initialValue: 0.0, trigger: swayTrigger) { content, angle in
            content.rotationEffect(.degrees(angle), anchor: .top)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(swayDirection * 2.4, duration: 0.12)
                CubicKeyframe(swayDirection * -1.7, duration: 0.16)
                CubicKeyframe(swayDirection * 0.8, duration: 0.13)
                CubicKeyframe(0.0, duration: 0.18)
            }
        }
    }
}

// MARK: - ClothespinView

private struct ClothespinView: View {
    var body: some View {
        Rectangle()
            .fill(Color(hex: "#D8A77A"))
            .frame(width: 14, height: 37)
            .rotationEffect(.degrees(1.5))
            .shadow(color: Color.black.opacity(0.16), radius: 2, x: 1, y: 2)
        .frame(width: 28, height: 44)
        .allowsHitTesting(false)
    }
}

// MARK: - RankingCardView

private struct RankingCardView: View {
    let item: FeedItem
    let rank: Int
    let onAuthorTapped: (String) -> Void

    private let cardWidth: CGFloat = 260
    private let cardHeight: CGFloat = 360
    private let imageSize: CGFloat = 222

    var body: some View {
        card
            .frame(width: cardWidth, height: cardHeight)
    }

    private var card: some View {
        VStack(spacing: 0) {
            AuthenticatedImageView(path: item.imageURL)
                .scaledToFill()
                .frame(width: imageSize, height: imageSize)
                .clipped()
                .overlay(
                    Rectangle()
                        .stroke(Color.filterzGray45.opacity(0.75), lineWidth: 1)
                )
                .padding(.top, 18)

            VStack(alignment: .leading, spacing: 7) {
                Button {
                    onAuthorTapped(item.authorId)
                } label: {
                    Text(item.authorNick)
                        .font(.pretendard(12, weight: .semibold))
                        .foregroundColor(.filterzAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(.plain)

                Text(item.title)
                    .font(.filterzDisplay(24))
                    .foregroundColor(.filterzGray30)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                HStack(alignment: .bottom) {
                    Text("#\(displayHashTag(item.hashtag))")
                        .font(.pretendard(13, weight: .medium))
                        .foregroundColor(.filterzGray30)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 12)

                    Text("\(rank)")
                        .font(.filterzDisplay(17))
                        .foregroundColor(.filterzAccent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(Color.filterzBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(Color.filterzGray45.opacity(0.85), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .shadow(color: Color.black.opacity(0.24), radius: 8, x: 4, y: 5)
    }
}
