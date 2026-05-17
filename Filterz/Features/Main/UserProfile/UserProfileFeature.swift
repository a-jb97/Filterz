import ComposableArchitecture
import Foundation

struct UserProfile: Equatable, Sendable {
    let userId: String
    let nick: String
    let name: String?
    let introduction: String?
    let profileImagePath: String?
    let hashTags: [String]

    init(dto: UserProfileResponseDTO) {
        userId = dto.userID
        nick = dto.nick
        name = dto.name
        introduction = dto.introduction
        profileImagePath = dto.profileImage
        hashTags = dto.hashTags
    }
}

@Reducer
struct UserProfileFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        let userId: String
        var profile: UserProfile? = nil
        var filters: [FeedItem] = []
        var selectedCategory: FilterCategory? = nil
        var nextCursor: String? = nil
        var isLoading: Bool = false
        var isFiltersLoading: Bool = false
        var hasMoreFilters: Bool = true
        var errorMessage: String? = nil

        var id: String { userId }
    }

    enum Action: Sendable {
        case onAppear
        case retryTapped
        case profileResponse(Result<UserProfileResponseDTO, any Error>)
        case filterCategorySelected(FilterCategory?)
        case loadMoreFilters
        case filtersResponse(Result<FilterSummaryPaginationListResponseDTO, any Error>, append: Bool)
        case filterTapped(id: String)
        case errorDismissed
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case filterTapped(id: String)
        }
    }

    @Dependency(\.userClient) var userClient
    @Dependency(\.filterClient) var filterClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let profileEffect = fetchProfile(&state)
                let filtersEffect = state.filters.isEmpty ? fetchFilters(&state, append: false) : Effect<Action>.none
                return .merge(profileEffect, filtersEffect)

            case .retryTapped:
                return .merge(
                    fetchProfile(&state, force: true),
                    fetchFilters(&state, append: false)
                )

            case .profileResponse(.success(let dto)):
                state.isLoading = false
                state.profile = UserProfile(dto: dto)
                return .none

            case .profileResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = displayMessage(for: error)
                return .none

            case .filterCategorySelected(let category):
                guard state.selectedCategory != category else { return .none }
                state.selectedCategory = category
                return fetchFilters(&state, append: false)

            case .loadMoreFilters:
                return fetchFilters(&state, append: true)

            case .filtersResponse(.success(let dto), let append):
                state.isFiltersLoading = false
                let items = dto.data.map { FeedItem(dto: $0) }
                state.filters = append ? state.filters + items : items
                state.nextCursor = dto.nextCursor
                state.hasMoreFilters = dto.nextCursor != nil && dto.nextCursor != "0"
                return .none

            case .filtersResponse(.failure(let error), _):
                state.isFiltersLoading = false
                state.errorMessage = displayMessage(for: error)
                return .none

            case .filterTapped(let id):
                return .send(.delegate(.filterTapped(id: id)))

            case .errorDismissed:
                state.errorMessage = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func fetchProfile(_ state: inout State, force: Bool = false) -> Effect<Action> {
        guard force || state.profile == nil else { return .none }
        guard !state.isLoading else { return .none }
        state.isLoading = true
        state.errorMessage = nil
        let userId = state.userId
        return .run { send in
            await send(.profileResponse(Result { try await userClient.userProfile(userId) }))
        }
    }

    private func fetchFilters(_ state: inout State, append: Bool) -> Effect<Action> {
        guard !state.isFiltersLoading else { return .none }
        guard !append || state.hasMoreFilters else { return .none }
        state.isFiltersLoading = true
        if !append {
            state.filters = []
            state.nextCursor = nil
            state.hasMoreFilters = true
        }
        state.errorMessage = nil
        let userId = state.userId
        let query = UserFilterListRequestDTO(
            next: append ? state.nextCursor : nil,
            limit: 10,
            category: state.selectedCategory?.categoryString
        )
        return .run { [filterClient] send in
            await send(.filtersResponse(
                Result { try await filterClient.getUserFilters(userId, query) },
                append: append
            ))
        }
    }
}

nonisolated private func displayMessage(for error: any Error) -> String {
    (error as? NetworkError)?.errorDescription ?? error.localizedDescription
}
