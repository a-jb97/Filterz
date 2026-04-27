import SwiftUI
import UIKit
import ComposableArchitecture

struct HeroBannerView: View {
    let store: StoreOf<HomeFeature>
    @State private var heroImage: UIImage? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            // 배경 이미지
            if let heroImage {
                Image(uiImage: heroImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 555)
                    .clipped()
            } else {
                Color(hex: "#2A3A2A")
                    .frame(maxWidth: .infinity)
                    .frame(height: 555)
            }

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

            // "사용해보기" 버튼 — 우상단
            VStack {
                HStack {
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
                .padding(.trailing, 20)
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
        .task(id: store.todayFilterImageURLs.first) {
            await loadHeroImage()
        }
    }

    private func loadHeroImage() async {
        guard let urlString = store.todayFilterImageURLs.first,
              let url = URL(string: APIKey.baseURL + urlString) else { return }
        var request = URLRequest(url: url)
        request.setValue(APIKey.apiKey, forHTTPHeaderField: "SeSACKey")
        request.setValue(APIKey.accessToken, forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let image = UIImage(data: data) else { return }
        heroImage = image
    }
}
