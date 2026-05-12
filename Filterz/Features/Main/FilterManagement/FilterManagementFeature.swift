import ComposableArchitecture
import Foundation

struct PurchasedFilterItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let description: String
    let imageURL: String?
    let authorId: String
    let authorNick: String
    let category: String
    let price: Int
    let purchasedAt: String?
    let createdAt: String
    let filterValues: FilterAdjustmentValues

    var feedItem: FeedItem {
        FeedItem(
            id: id,
            authorId: authorId,
            title: title,
            description: description,
            imageURL: imageURL,
            authorName: authorNick,
            authorNick: authorNick,
            likeCount: 0,
            buyerCount: 0,
            hashtag: category,
            isLiked: false,
            createdAt: createdAt
        )
    }

    init(order: OrderResponseDTO) {
        let filter = order.filter
        id = filter.id
        title = filter.title
        description = filter.description
        imageURL = filter.files.first
        authorId = filter.creator.userID
        authorNick = filter.creator.nick
        category = filter.category
        price = filter.price
        purchasedAt = order.paidAt ?? order.createdAt
        createdAt = filter.createdAt
        filterValues = FilterAdjustmentValues(dto: filter.filterValues)
    }

    init(detail: FilterResponseDTO) {
        id = detail.filterId
        title = detail.title
        description = detail.description
        imageURL = detail.files.first
        authorId = detail.creator.userID
        authorNick = detail.creator.nick
        category = detail.category
        price = detail.price
        purchasedAt = nil
        createdAt = detail.createdAt
        filterValues = FilterAdjustmentValues(dto: detail.filterValues)
    }
}

@Reducer
struct FilterManagementFeature {
    struct AvailableFiltersPayload: Sendable {
        let purchasedOrders: [OrderResponseDTO]
        let ownedDetails: [FilterResponseDTO]
    }

    @ObservableState
    struct State: Equatable {
        var items: [PurchasedFilterItem] = []
        var isLoading = false
        var isCameraPresented = false
        var errorMessage: String?

        var feedItems: [FeedItem] {
            items.map(\.feedItem)
        }
    }

    enum Action: Sendable {
        case onAppear
        case refresh
        case availableFiltersResponse(Result<AvailableFiltersPayload, any Error>)
        case uploadButtonTapped
        case cameraButtonTapped
        case cameraDismissed
        case filterTapped(id: String)
        case errorDismissed
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case uploadRequested
            case filterDetailRequested(id: String)
        }
    }

    @Dependency(\.paymentClient) var paymentClient
    @Dependency(\.userClient) var userClient
    @Dependency(\.filterClient) var filterClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.items.isEmpty else { return .none }
                return fetchOrders(&state)

            case .refresh:
                return fetchOrders(&state)

            case .availableFiltersResponse(.success(let payload)):
                state.isLoading = false
                state.items = mergedItems(
                    purchased: payload.purchasedOrders.map(PurchasedFilterItem.init(order:)),
                    owned: payload.ownedDetails.map(PurchasedFilterItem.init(detail:))
                )
                return .none

            case .availableFiltersResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = displayMessage(for: error)
                return .none

            case .uploadButtonTapped:
                return .send(.delegate(.uploadRequested))

            case .cameraButtonTapped:
                state.isCameraPresented = true
                return .none

            case .cameraDismissed:
                state.isCameraPresented = false
                return .none

            case .filterTapped(let id):
                return .send(.delegate(.filterDetailRequested(id: id)))

            case .errorDismissed:
                state.errorMessage = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func fetchOrders(_ state: inout State) -> Effect<Action> {
        guard !state.isLoading else { return .none }
        state.isLoading = true
        state.errorMessage = nil
        return .run { [paymentClient, userClient, filterClient] send in
            async let purchasedOrders = loadPurchasedOrders(paymentClient)
            async let ownedDetails = loadOwnedFilterDetails(userClient, filterClient)
            await send(.availableFiltersResponse(.success(AvailableFiltersPayload(
                purchasedOrders: purchasedOrders,
                ownedDetails: ownedDetails
            ))))
        }
    }
}

nonisolated private func mergedItems(
    purchased: [PurchasedFilterItem],
    owned: [PurchasedFilterItem]
) -> [PurchasedFilterItem] {
    var seen = Set<String>()
    return (owned + purchased)
        .filter { item in
            guard !seen.contains(item.id) else { return false }
            seen.insert(item.id)
            return true
        }
        .sorted {
            ($0.purchasedAt ?? $0.createdAt) > ($1.purchasedAt ?? $1.createdAt)
        }
}

private func loadPurchasedOrders(_ paymentClient: PaymentClient) async -> [OrderResponseDTO] {
    do {
        return try await paymentClient.getOrders()
    } catch {
        return []
    }
}

private func loadOwnedFilterDetails(
    _ userClient: UserClient,
    _ filterClient: FilterClient
) async -> [FilterResponseDTO] {
    do {
        let profile = try await userClient.myInfo()
        var summaries: [FilterSummaryResponseDTO] = []
        var seenIds = Set<String>()
        var cursor: String?
        repeat {
            let page = try await filterClient.getUserFilters(
                profile.userID,
                UserFilterListRequestDTO(next: cursor, limit: 20, category: nil)
            )
            let newItems = page.data.filter { !seenIds.contains($0.filterId) }
            newItems.forEach { seenIds.insert($0.filterId) }
            summaries.append(contentsOf: newItems)
            cursor = page.nextCursor
        } while cursor != nil && cursor != "0"

        var details: [FilterResponseDTO] = []
        for summary in summaries {
            if let detail = try? await filterClient.getFilterDetail(summary.filterId) {
                details.append(detail)
            }
        }
        return details
    } catch {
        return []
    }
}

nonisolated private func displayMessage(for error: any Error) -> String {
    (error as? NetworkError)?.errorDescription ?? error.localizedDescription
}
