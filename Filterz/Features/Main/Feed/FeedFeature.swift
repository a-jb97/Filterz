import ComposableArchitecture
import Foundation

// MARK: - Domain Model

struct FeedItem: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let imageURL: String?
    let authorName: String
    let authorNick: String
    let likeCount: Int
    let buyerCount: Int
    let hashtag: String
    let isLiked: Bool
    let createdAt: String
}

extension FeedItem {
    init(dto: FilterSummaryResponseDTO) {
        id = dto.filterId
        title = dto.title
        description = dto.description
        imageURL = dto.files.first
        authorName = dto.creator.nick
        authorNick = dto.creator.nick
        likeCount = dto.likeCount
        buyerCount = dto.buyerCount
        hashtag = dto.category
        isLiked = dto.isLiked
        createdAt = dto.createdAt
    }
}

// MARK: - FeedFeature

@Reducer
struct FeedFeature {

    enum SortMode: Equatable, CaseIterable {
        case popular, purchase, latest

        var title: String {
            switch self {
            case .popular:  return "인기순"
            case .purchase: return "구매순"
            case .latest:   return "최신순"
            }
        }
    }

    enum ViewMode: Equatable {
        case block, list

        var title: String {
            switch self {
            case .block: return "Block Mode"
            case .list:  return "List Mode"
            }
        }

        var toggled: ViewMode {
            self == .block ? .list : .block
        }
    }

    @ObservableState
    struct State: Equatable {
        var sortMode: SortMode = .popular
        var viewMode: ViewMode = .block
        var topRankingItems: [FeedItem] = []
        var feedItems: [FeedItem] = []
        var isLoading: Bool = false
    }

    enum Action: Sendable {
        case onAppear
        case sortChanged(SortMode)
        case viewModeToggled
        case topRankingResponse(Result<FilterSummaryListResponseDTO, any Error>)
        case feedResponse(Result<FilterSummaryListResponseDTO, any Error>)
    }

    @Dependency(\.filterClient) var filterClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                return .merge(
                    .run { send in
                        await send(.topRankingResponse(
                            Result { try await filterClient.getHotTrendFilters() }
                        ))
                    },
                    .run { send in
                        await send(.feedResponse(
                            Result { try await filterClient.getFilters() }
                        ))
                    }
                )

            case .sortChanged(let mode):
                state.sortMode = mode
                state.feedItems = state.feedItems.sorted(by: mode.comparator)
                return .none

            case .viewModeToggled:
                state.viewMode = state.viewMode.toggled
                return .none

            case .topRankingResponse(.success(let dto)):
                state.isLoading = false
                state.topRankingItems = Array(dto.data.prefix(10)).map { FeedItem(dto: $0) }
                return .none

            case .topRankingResponse(.failure):
                state.isLoading = false
                return .none

            case .feedResponse(.success(let dto)):
                let items = dto.data.map { FeedItem(dto: $0) }
                state.feedItems = items.sorted(by: state.sortMode.comparator)
                return .none

            case .feedResponse(.failure):
                return .none
            }
        }
    }
}

private extension FeedFeature.SortMode {
    var comparator: (FeedItem, FeedItem) -> Bool {
        switch self {
        case .popular:  return { $0.likeCount > $1.likeCount }
        case .purchase: return { $0.buyerCount > $1.buyerCount }
        case .latest:   return { $0.createdAt > $1.createdAt }
        }
    }
}
