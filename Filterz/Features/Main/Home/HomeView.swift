import SwiftUI
import ComposableArchitecture

struct HomeView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                HeroBannerView(store: store)
                CategoryBarView()
                TodayBannerView(
                    currentPage: store.todayBannerCurrentPage,
                    totalPages: store.todayBannerTotalPages
                )
                HotTrendView(filters: store.hotFilters)
                FeaturedArtistView(artist: store.featuredArtist)
                Spacer().frame(height: 100)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.filterzBlackBase)
        .onAppear { store.send(.onAppear) }
    }
}
