import SwiftUI

struct HotFilterCardView: View {
    let item: HotFilterItem
    var isFocused: Bool = true
    var onTap: () -> Void = {}

    private let cardWidth: CGFloat = 200
    private let cardHeight: CGFloat = 260
    private let cardPadding: CGFloat = 8
    private let imageHeight: CGFloat = 176

    private var imageWidth: CGFloat {
        cardWidth - (cardPadding * 2)
    }

    var body: some View {
        VStack(spacing: 0) {
            AuthenticatedImageView(path: item.imageURL)
                .frame(width: imageWidth, height: imageHeight)
                .background(Color.filterzBackground)
                .clipped()
                .overlay(
                    Rectangle()
                        .stroke(Color.filterzGray45.opacity(0.75), lineWidth: 1)
                )
                .padding(.top, cardPadding)
                .padding(.horizontal, cardPadding)

            footerView
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(Color.filterzPolaroid)
        .overlay(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(Color.filterzGray45.opacity(0.85), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .shadow(color: Color.black.opacity(isFocused ? 0.24 : 0.12), radius: 8, x: 4, y: 5)
        .opacity(isFocused ? 1.0 : 0.55)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private var footerView: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(item.name)
                .font(.filterzDisplay(18))
                .foregroundColor(.filterzGray30)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 13, height: 12)
                    .foregroundColor(.filterzAccent)

                Text("\(item.likeCount)")
                    .font(.pretendard(12, weight: .semibold))
                    .foregroundColor(.filterzGray30)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }
}
