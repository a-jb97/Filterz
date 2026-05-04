import ComposableArchitecture
import Foundation

// MARK: - Domain Model

struct FeedItem: Identifiable, Equatable {
    let id: String
    let authorId: String
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
        authorId = dto.creator.userID
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
        var allFeedItems: [FeedItem] = []
        var feedItems: [FeedItem] = []
        var selectedCategory: FilterCategory? = nil
        var isLoading: Bool = false
    }

    enum Action: Sendable {
        case onAppear
        case sortChanged(SortMode)
        case viewModeToggled
        case topRankingResponse(Result<FilterSummaryListResponseDTO, any Error>)
        case feedResponse(Result<[FilterSummaryResponseDTO], any Error>)
        case feedItemTapped(id: String)
        case topRankingItemTapped(id: String)
        case authorProfileTapped(userId: String)
        case categorySelected(FilterCategory?)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case filterTapped(id: String)
            case userProfileTapped(userId: String)
        }
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
                    fetchFeedEffect(category: state.selectedCategory)
                )

            case .sortChanged(let mode):
                state.sortMode = mode
                state.feedItems = state.allFeedItems.sorted(by: mode.comparator)
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

            case .feedResponse(.success(let data)):
                let items = data.map { FeedItem(dto: $0) }
                state.allFeedItems = items
                state.feedItems = items.sorted(by: state.sortMode.comparator)
                return .none

            case .feedResponse(.failure):
                return .none

            case .feedItemTapped(let id), .topRankingItemTapped(let id):
                return .send(.delegate(.filterTapped(id: id)))

            case .authorProfileTapped(let userId):
                return .send(.delegate(.userProfileTapped(userId: userId)))

            case .categorySelected(let category):
                state.selectedCategory = category
                state.allFeedItems = []
                state.feedItems = []
                return fetchFeedEffect(category: category)

            case .delegate:
                return .none
            }
        }
    }

    private func fetchFeedEffect(category: FilterCategory?) -> Effect<Action> {
        .run { [filterClient] send in
            do {
                var allData: [FilterSummaryResponseDTO] = []
                var seenIds = Set<String>()
                var cursor: String? = nil
                repeat {
                    let page = try await filterClient.getFilters(cursor, category?.categoryString)
                    let newItems = page.data.filter { !seenIds.contains($0.filterId) }
                    if newItems.isEmpty { break }
                    newItems.forEach { seenIds.insert($0.filterId) }
                    allData.append(contentsOf: newItems)
                    cursor = page.nextCursor
                } while cursor != nil && cursor != "0"
                await send(.feedResponse(.success(allData)))
            } catch {
                await send(.feedResponse(.failure(error)))
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
