import ComposableArchitecture

// MARK: - Placeholder Models

struct HotFilterItem: Identifiable, Equatable {
    let id: String
    let name: String
    let likeCount: Int

    static let placeholders: [HotFilterItem] = [
        .init(id: "1", name: "강철", likeCount: 30),
        .init(id: "2", name: "소낙새", likeCount: 121),
        .init(id: "3", name: "화양연화", likeCount: 226)
    ]
}

struct ArtistItem: Equatable {
    let name: String
    let nameEn: String
    let quote: String
    let bio: String
    let tags: [String]
    let workCount: Int

    static let placeholder = ArtistItem(
        name: "윤새싹",
        nameEn: "SESAC YOON",
        quote: "\"자연의 섬세함을 담아내는 감성 사진작가\"",
        bio: "윤새싹은 자연의 섬세한 아름다움을 포착하는 데 탁월한 감각을 지닌 사진작가입니다. 그녀의 작품은 일상 속에서 쉽게 지나칠 수 있는 순간들을 특별하게 담아내며, 관람객들에게 새로운 시각을 선사합니다.",
        tags: ["섬세함", "자연", "미니멀"],
        workCount: 3
    )
}

// MARK: - HomeFeature

@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        var todayFilterTitle: String = "새싹을 담은 필터"
        var todayFilterSubtitle: String = "청록 새록"
        var todayFilterDescription: String = "햇살 아래 돋아나는 새싹처럼,\n맑고 투명한 빛을 담은 자연 감성 필터입니다.\n너무 과하지 않게, 부드러운 색감으로 분위기를 살려줍니다.\n새로운 시작, 순수한 감정을 담고 싶을 때 이 필터를 사용해보세요."
        var todayBannerCurrentPage: Int = 1
        var todayBannerTotalPages: Int = 12
        var hotFilters: [HotFilterItem] = HotFilterItem.placeholders
        var featuredArtist: ArtistItem = .placeholder
    }

    enum Action: Sendable {
        case onAppear
        case tryFilterTapped
    }

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            return .none
        }
    }
}
