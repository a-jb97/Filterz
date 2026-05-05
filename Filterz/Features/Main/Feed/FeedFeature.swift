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

    nonisolated struct SearchUser: Equatable, Sendable, Identifiable {
        let userId: String
        let nick: String
        let profileImagePath: String?

        var id: String { userId }

        init(dto: UserInfoResponseDTO) {
            userId = dto.userID
            nick = dto.nick
            profileImagePath = dto.profileImage
        }
    }

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
        var isSearchPresented: Bool = false
        var searchText: String = ""
        var isSearchingUsers: Bool = false
        var searchUsers: IdentifiedArrayOf<SearchUser> = []
        var selectedSearchUser: SearchUser? = nil
        var searchedUserFilters: [FeedItem] = []
        var isLoadingUserFilters: Bool = false
        var userFilterNextCursor: String? = nil
        var hasMoreUserFilters: Bool = true
        var errorMessage: String? = nil
    }

    enum Action: Sendable {
        case onAppear
        case sortChanged(SortMode)
        case viewModeToggled
        case topRankingResponse(Result<FilterSummaryListResponseDTO, any Error>)
        case feedResponse(Result<[FilterSummaryResponseDTO], any Error>)
        case searchButtonTapped
        case videoButtonTapped
        case searchTextChanged(String)
        case userSearchResponse(Result<[SearchUser], any Error>)
        case searchUserSelected(SearchUser)
        case userFiltersResponse(Result<FilterSummaryPaginationListResponseDTO, any Error>, append: Bool)
        case loadMoreUserFilters
        case feedItemTapped(id: String)
        case topRankingItemTapped(id: String)
        case authorProfileTapped(userId: String)
        case categorySelected(FilterCategory?)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case filterTapped(id: String)
            case userProfileTapped(userId: String)
            case videoListRequested
        }
    }

    @Dependency(\.filterClient) var filterClient
    @Dependency(\.userClient) var userClient
    @Dependency(\.continuousClock) var clock

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
                state.searchedUserFilters = state.searchedUserFilters.sorted(by: mode.comparator)
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

            case .searchButtonTapped:
                state.isSearchPresented.toggle()
                state.errorMessage = nil
                if !state.isSearchPresented {
                    resetSearchState(&state)
                    return .merge(
                        .cancel(id: "feedUserSearch"),
                        .cancel(id: "feedUserFilters")
                    )
                }
                return .none

            case .videoButtonTapped:
                return .send(.delegate(.videoListRequested))

            case .searchTextChanged(let text):
                guard state.searchText != text else { return .none }
                state.searchText = text
                state.errorMessage = nil
                state.selectedSearchUser = nil
                state.searchedUserFilters = []
                state.isLoadingUserFilters = false
                state.userFilterNextCursor = nil
                state.hasMoreUserFilters = true
                let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else {
                    state.isSearchingUsers = false
                    state.searchUsers.removeAll()
                    return .merge(
                        .cancel(id: "feedUserSearch"),
                        .cancel(id: "feedUserFilters")
                    )
                }
                state.isSearchingUsers = true
                let searchEffect = Effect<Action>.run { [userClient, clock] send in
                    try await clock.sleep(for: .milliseconds(300))
                    let currentUserId = KeychainHelper.load(forKey: "userId") ?? ""
                    let users = try await userClient.searchUsers(query)
                        .filter { $0.userID != currentUserId }
                        .map(SearchUser.init(dto:))
                    await send(.userSearchResponse(.success(users)))
                } catch: { error, send in
                    guard !(error is CancellationError) else { return }
                    await send(.userSearchResponse(.failure(error)))
                }
                .cancellable(id: "feedUserSearch", cancelInFlight: true)
                return .merge(searchEffect, .cancel(id: "feedUserFilters"))

            case .userSearchResponse(.success(let users)):
                state.isSearchingUsers = false
                state.searchUsers = IdentifiedArray(uniqueElements: users)
                return .none

            case .userSearchResponse(.failure(let error)):
                state.isSearchingUsers = false
                state.searchUsers.removeAll()
                state.errorMessage = error.localizedDescription
                return .none

            case .searchUserSelected(let user):
                state.selectedSearchUser = user
                state.searchedUserFilters = []
                state.isLoadingUserFilters = false
                state.userFilterNextCursor = nil
                state.hasMoreUserFilters = true
                return fetchUserFiltersEffect(&state, append: false)

            case .userFiltersResponse(.success(let dto), let append):
                state.isLoadingUserFilters = false
                let items = dto.data.map { FeedItem(dto: $0) }
                let merged = append ? state.searchedUserFilters + items : items
                state.searchedUserFilters = merged.sorted(by: state.sortMode.comparator)
                state.userFilterNextCursor = dto.nextCursor
                state.hasMoreUserFilters = dto.nextCursor != nil && dto.nextCursor != "0"
                return .none

            case .userFiltersResponse(.failure(let error), _):
                state.isLoadingUserFilters = false
                state.errorMessage = error.localizedDescription
                return .none

            case .loadMoreUserFilters:
                return fetchUserFiltersEffect(&state, append: true)

            case .feedItemTapped(let id), .topRankingItemTapped(let id):
                return .send(.delegate(.filterTapped(id: id)))

            case .authorProfileTapped(let userId):
                return .send(.delegate(.userProfileTapped(userId: userId)))

            case .categorySelected(let category):
                state.selectedCategory = category
                if state.isSearchPresented, state.selectedSearchUser != nil {
                    state.searchedUserFilters = []
                    state.isLoadingUserFilters = false
                    state.userFilterNextCursor = nil
                    state.hasMoreUserFilters = true
                    return fetchUserFiltersEffect(&state, append: false)
                }
                state.allFeedItems = []
                state.feedItems = []
                return fetchFeedEffect(category: category)

            case .delegate:
                return .none
            }
        }
    }

    private func resetSearchState(_ state: inout State) {
        state.searchText = ""
        state.isSearchingUsers = false
        state.searchUsers.removeAll()
        state.selectedSearchUser = nil
        state.searchedUserFilters = []
        state.isLoadingUserFilters = false
        state.userFilterNextCursor = nil
        state.hasMoreUserFilters = true
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

    private func fetchUserFiltersEffect(_ state: inout State, append: Bool) -> Effect<Action> {
        guard let user = state.selectedSearchUser else { return .none }
        guard !state.isLoadingUserFilters else { return .none }
        guard !append || state.hasMoreUserFilters else { return .none }
        state.isLoadingUserFilters = true
        state.errorMessage = nil
        let query = UserFilterListRequestDTO(
            next: append ? state.userFilterNextCursor : nil,
            limit: 10,
            category: state.selectedCategory?.categoryString
        )
        return .run { [filterClient] send in
            await send(.userFiltersResponse(
                Result { try await filterClient.getUserFilters(user.userId, query) },
                append: append
            ))
        }
        .cancellable(id: "feedUserFilters", cancelInFlight: true)
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
