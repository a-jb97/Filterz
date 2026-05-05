import SwiftUI
import ComposableArchitecture

struct HeroBannerView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        ZStack(alignment: .bottom) {
            // 배경 이미지
            AuthenticatedImageView(path: store.todayFilterImageURLs.first)
                .frame(maxWidth: .infinity)
                .frame(height: 555)
                .background(Color(hex: "#2A3A2A"))
                .clipped()

            // 하단 그라디언트 오버레이
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.25),
                    .init(color: Color.filterzBlackBase, location: 0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity)
            .frame(height: 555)

            // 상단 로고와 "사용해보기" 버튼
            VStack {
                HStack(alignment: .center) {
                    (
                        Text("FILTER")
                            .foregroundColor(.filterzGray30)
                        + Text("Z")
                            .foregroundColor(.filterzAccent)
                    )
                    .font(.filterzDisplay(24))

                    Spacer()

                    Button {
                        store.send(.tryFilterTapped)
                    } label: {
                        Text("사용해보기")
                            .font(.pretendard(12, weight: .medium))
                            .foregroundColor(.filterzGray60)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.filterzTranslucent)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.filterzTranslucent, lineWidth: 1)
                                    )
                            )
                    }
                }
                .padding(.top, 64)
                .padding(.horizontal, 20)
                Spacer()
            }

            // 하단 텍스트 블록
            VStack(alignment: .leading, spacing: 4) {
                Text("오늘의 필터 소개")
                    .font(.pretendard(13, weight: .medium))
                    .foregroundColor(.filterzGray60)

                Text(store.todayFilterTitle)
                    .font(.custom("ClimateCrisisKR-1979", size: 32))
                    .foregroundColor(.filterzGray30)

                Text(store.todayFilterSubtitle)
                    .font(.custom("ClimateCrisisKR-1979", size: 32))
                    .foregroundColor(.filterzGray30)

                Spacer().frame(height: 12)

                Text(store.todayFilterDescription)
                    .font(.pretendard(12, weight: .regular))
                    .foregroundColor(.filterzGray60)
                    .lineSpacing(12 * 0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .frame(height: 555)
    }
}
