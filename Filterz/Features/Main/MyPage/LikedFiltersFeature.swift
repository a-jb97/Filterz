import ComposableArchitecture
import Foundation

@Reducer
struct LikedFiltersFeature {
    @ObservableState
    struct State: Equatable {
        var items: [FeedItem] = []
        var selectedCategory: FilterCategory? = nil
        var nextCursor: String? = nil
        var isLoading: Bool = false
        var hasMore: Bool = true
        var errorMessage: String? = nil
    }

    enum Action: Sendable {
        case onAppear
        case backTapped
        case categorySelected(FilterCategory?)
        case loadMore
        case response(Result<FilterSummaryPaginationListResponseDTO, any Error>, append: Bool)
        case filterTapped(id: String)
        case errorDismissed
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case backTapped
            case filterTapped(id: String)
        }
    }

    @Dependency(\.filterClient) var filterClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return state.items.isEmpty ? fetchLikedFilters(&state, append: false) : .none

            case .backTapped:
                return .send(.delegate(.backTapped))

            case .categorySelected(let category):
                guard state.selectedCategory != category else { return .none }
                state.selectedCategory = category
                return fetchLikedFilters(&state, append: false)

            case .loadMore:
                return fetchLikedFilters(&state, append: true)

            case .response(.success(let dto), let append):
                state.isLoading = false
                let items = dto.data.map { FeedItem(dto: $0) }
                state.items = append ? state.items + items : items
                state.nextCursor = dto.nextCursor
                state.hasMore = dto.nextCursor != nil && dto.nextCursor != "0"
                return .none

            case .response(.failure(let error), _):
                state.isLoading = false
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

    private func fetchLikedFilters(_ state: inout State, append: Bool) -> Effect<Action> {
        guard !state.isLoading else { return .none }
        guard !append || state.hasMore else { return .none }
        state.isLoading = true
        if !append {
            state.items = []
            state.nextCursor = nil
            state.hasMore = true
        }
        state.errorMessage = nil
        let query = LikedFilterListRequestDTO(
            next: append ? state.nextCursor : nil,
            limit: 10,
            category: state.selectedCategory?.categoryString
        )
        return .run { [filterClient] send in
            await send(.response(
                Result { try await filterClient.getLikedFilters(query) },
                append: append
            ))
        }
    }
}

nonisolated private func displayMessage(for error: any Error) -> String {
    (error as? NetworkError)?.errorDescription ?? error.localizedDescription
}
