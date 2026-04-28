import ComposableArchitecture
import Foundation

// MARK: - Placeholder Models

struct HotFilterItem: Identifiable, Equatable {
    let id: String
    let name: String
    let likeCount: Int
    let imageURL: String?
}

extension HotFilterItem {
    init(dto: FilterSummaryResponseDTO) {
        id = dto.filterId
        name = dto.title
        likeCount = dto.likeCount
        imageURL = dto.files.first
    }
}

struct ArtistFilterWork: Identifiable, Equatable {
    let id: String
    let imageURL: String?
}

struct ArtistItem: Equatable {
    let name: String
    let nameEn: String
    let profileImagePath: String?
    let quote: String
    let bio: String
    let tags: [String]
    let filterWorks: [ArtistFilterWork]

    static let placeholder = ArtistItem(
        name: "윤새싹",
        nameEn: "SESAC YOON",
        profileImagePath: nil,
        quote: "\"자연의 섬세함을 담아내는 감성 사진작가\"",
        bio: "윤새싹은 자연의 섬세한 아름다움을 포착하는 데 탁월한 감각을 지닌 사진작가입니다. 그녀의 작품은 일상 속에서 쉽게 지나칠 수 있는 순간들을 특별하게 담아내며, 관람객들에게 새로운 시각을 선사합니다.",
        tags: ["섬세함", "자연", "미니멀"],
        filterWorks: []
    )
}

extension ArtistItem {
    init(dto: TodayAuthorResponseDTO) {
        let user = dto.author
        name = user.nick
        nameEn = user.name ?? ""
        profileImagePath = user.profileImage
        quote = user.introduction ?? ""
        bio = user.description ?? ""
        tags = (user.hashTags ?? []).map { $0.hasPrefix("#") ? String($0.dropFirst()) : $0 }
        filterWorks = (dto.filters ?? []).map { ArtistFilterWork(id: $0.filterId, imageURL: $0.files.first) }
    }
}

// MARK: - HomeFeature

@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        var isLoading: Bool = false
        var todayFilterId: String = ""
        var todayFilterTitle: String = ""
        var todayFilterSubtitle: String = ""
        var todayFilterDescription: String = ""
        var todayFilterImageURLs: [String] = []
        var banners: [BannerDTO] = []
        var currentBannerPage: Int = 0
        var bannerWebURL: URL? = nil
        var hotFilters: [HotFilterItem] = []
        var featuredArtist: ArtistItem = .placeholder
    }

    enum Action: Sendable {
        case onAppear
        case tryFilterTapped
        case todayFilterResponse(Result<TodayFilterResponseDTO, any Error>)
        case fetchBanners
        case bannersResponse(Result<BannerListResponseDTO, any Error>)
        case bannerPageChanged(Int)
        case bannerTapped(BannerDTO)
        case bannerWebViewDismissed
        case hotTrendFiltersResponse(Result<FilterSummaryListResponseDTO, any Error>)
        case hotFilterTapped(id: String)
        case todayAuthorResponse(Result<TodayAuthorResponseDTO, any Error>)
        case todayAuthorFilterTapped(filterId: String)
    }

    @Dependency(\.filterClient) var filterClient
    @Dependency(\.bannerClient) var bannerClient
    @Dependency(\.userClient) var userClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                return .merge(
                    .run { send in
                        await send(.todayFilterResponse(
                            Result { try await filterClient.getTodayFilter() }
                        ))
                    },
                    .send(.fetchBanners),
                    .run { send in
                        await send(.hotTrendFiltersResponse(
                            Result { try await filterClient.getHotTrendFilters() }
                        ))
                    },
                    .run { send in
                        await send(.todayAuthorResponse(
                            Result { try await userClient.getTodayAuthor() }
                        ))
                    }
                )

            case .todayFilterResponse(.success(let dto)):
                state.isLoading = false
                state.todayFilterId = dto.filterId
                state.todayFilterTitle = dto.title
                state.todayFilterSubtitle = dto.introduction
                state.todayFilterDescription = dto.description
                state.todayFilterImageURLs = dto.files
                return .none

            case .todayFilterResponse(.failure):
                state.isLoading = false
                state.todayFilterTitle = "새싹을 담은 필터"
                state.todayFilterSubtitle = "청록 새록"
                state.todayFilterDescription = "햇살 아래 돋아나는 새싹처럼,\n맑고 투명한 빛을 담은 자연 감성 필터입니다.\n너무 과하지 않게, 부드러운 색감으로 분위기를 살려줍니다.\n새로운 시작, 순수한 감정을 담고 싶을 때 이 필터를 사용해보세요."
                return .none

            case .fetchBanners:
                return .run { send in
                    await send(.bannersResponse(
                        Result { try await bannerClient.getBanners() }
                    ))
                }

            case .bannersResponse(.success(let dto)):
                state.banners = dto.data
                return .none

            case .bannersResponse(.failure):
                return .none

            case .bannerPageChanged(let page):
                state.currentBannerPage = page
                return .none

            case .bannerTapped(let banner):
                guard let payload = banner.payload,
                      payload.type == "WEBVIEW",
                      var components = URLComponents(string: APIKey.baseURL)
                else { return .none }
                components.path = payload.value
                guard let url = components.url else { return .none }
                state.bannerWebURL = url
                return .none

            case .bannerWebViewDismissed:
                state.bannerWebURL = nil
                return .none

            case .hotTrendFiltersResponse(.success(let dto)):
                state.hotFilters = dto.data.map { HotFilterItem(dto: $0) }
                return .none

            case .hotTrendFiltersResponse(.failure):
                return .none

            case .hotFilterTapped:
                return .none

            case .todayAuthorResponse(.success(let dto)):
                state.featuredArtist = ArtistItem(dto: dto)
                return .none

            case .todayAuthorResponse(.failure):
                return .none

            case .todayAuthorFilterTapped:
                return .none

            case .tryFilterTapped:
                return .none
            }
        }
    }
}
