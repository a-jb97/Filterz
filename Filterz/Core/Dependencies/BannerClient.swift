import ComposableArchitecture
import Foundation

struct BannerClient: Sendable {
    var getBanners: @Sendable () async throws -> BannerListResponseDTO
}

extension BannerClient: DependencyKey {
    static var liveValue: BannerClient {
        BannerClient(
            getBanners: {
                try await NetworkManager.shared.request(.getBanners)
            }
        )
    }
}

extension DependencyValues {
    var bannerClient: BannerClient {
        get { self[BannerClient.self] }
        set { self[BannerClient.self] = newValue }
    }
}
