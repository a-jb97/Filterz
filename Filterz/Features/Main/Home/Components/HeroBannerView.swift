import SwiftUI
import ComposableArchitecture

struct HeroBannerView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        GeometryReader { geo in
            let cardWidth = min(geo.size.width - 20, 400)
            let imageWidth = cardWidth - 36

            ZStack(alignment: .top) {
                Color.filterzBackground
                    .ignoresSafeArea(edges: .top)

                VStack(spacing: 0) {
                    topBezel
                        .frame(width: imageWidth)
                        .padding(.top, 16)

                    AuthenticatedImageView(path: store.todayFilterImageURLs.first)
                        .frame(width: imageWidth, height: 300)
                        .background(Color(hex: "#2A3A2A"))
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.send(.tryFilterTapped)
                        }
                        .overlay(
                            Rectangle()
                                .stroke(Color.filterzGray45.opacity(0.75), lineWidth: 1)
                        )
                        .padding(.top, 10)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("오늘의 필터 소개")
                            .font(.pretendard(15, weight: .medium))
                            .foregroundColor(.filterzAccent)

                        Text(store.todayFilterTitle)
                            .font(.filterzDisplay(30))
                            .foregroundColor(.filterzGray30)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(store.todayFilterSubtitle)
                            .font(.filterzDisplay(30))
                            .foregroundColor(.filterzGray30)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(store.todayFilterDescription)
                            .font(.pretendard(14, weight: .regular))
                            .foregroundColor(.filterzGray30)
                            .lineSpacing(14 * 0.7)
                            .lineLimit(2)
                            .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
                .frame(width: cardWidth)
                .background(Color.filterzPolaroid)
                .overlay(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .stroke(Color.filterzGray45.opacity(0.85), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                .shadow(color: Color.black.opacity(0.24), radius: 8, x: 4, y: 5)
                .padding(.top, 64)
            }
        }
        .frame(height: 620)
    }

    private var topBezel: some View {
        HStack(alignment: .center) {
            (
                Text("FILTER")
                    .foregroundColor(.filterzGray30)
                + Text("Z")
                    .foregroundColor(.filterzAccent)
            )
            .font(.filterzDisplay(24))

            Spacer()
        }
    }
}
