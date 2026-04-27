import SwiftUI
import UIKit
import ComposableArchitecture

struct TodayBannerView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        let banners = store.banners
        let currentPage = store.currentBannerPage

        ZStack(alignment: .bottomTrailing) {
            if banners.isEmpty {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(hex: "#1A2A3A"))
                    .frame(height: 100)
            } else {
                TabView(selection: Binding(
                    get: { currentPage },
                    set: { store.send(.bannerPageChanged($0)) }
                )) {
                    ForEach(Array(banners.enumerated()), id: \.offset) { index, banner in
                        BannerImageView(imageUrl: banner.imageUrl)
                            .tag(index)
                            .onTapGesture { store.send(.bannerTapped(banner)) }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 100)
            }

            if !banners.isEmpty {
                pageIndicator(current: currentPage + 1, total: banners.count)
                    .padding(.trailing, 12)
                    .padding(.bottom, 12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private func pageIndicator(current: Int, total: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.filterzGray75.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.filterzGray60, lineWidth: 1)
                )
                .frame(width: 44, height: 20)

            Text("\(current) / \(total)")
                .font(.pretendard(10, weight: .medium))
                .foregroundColor(.filterzGray45)
        }
    }
}

private struct BannerImageView: View {
    let imageUrl: String
    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(hex: "#1A2A3A")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .task(id: imageUrl) { await loadImage() }
    }

    private func loadImage() async {
        guard let url = URL(string: APIKey.baseURL + imageUrl) else { return }
        var request = URLRequest(url: url)
        request.setValue(APIKey.apiKey, forHTTPHeaderField: "SeSACKey")
        request.setValue(APIKey.accessToken, forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let loaded = UIImage(data: data) else { return }
        image = loaded
    }
}
