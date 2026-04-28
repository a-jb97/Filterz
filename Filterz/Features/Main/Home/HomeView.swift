import SwiftUI
import ComposableArchitecture

struct HomeView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                HeroBannerView(store: store)
                CategoryBarView(onCategoryTapped: { store.send(.categoryTapped($0)) })
                TodayBannerView(store: store)
                HotTrendView(
                    filters: store.hotFilters,
                    onFilterTapped: { id in store.send(.hotFilterTapped(id: id)) }
                )
                FeaturedArtistView(
                    artist: store.featuredArtist,
                    onFilterTapped: { id in store.send(.todayAuthorFilterTapped(filterId: id)) }
                )
                Spacer().frame(height: 100)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.filterzBlackBase)
        .onAppear { store.send(.onAppear) }
        .sheet(isPresented: Binding(
            get: { store.bannerWebURL != nil },
            set: { if !$0 { store.send(.bannerWebViewDismissed) } }
        )) {
            if let url = store.bannerWebURL {
                BannerWebView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
}
