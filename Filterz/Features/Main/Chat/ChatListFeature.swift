import ComposableArchitecture
import Foundation

@Reducer
struct ChatListFeature {

    @ObservableState
    struct State: Equatable {
        var rooms: IdentifiedArrayOf<ChatRoom> = []
        var isLoading: Bool = false
        var errorMessage: String? = nil
    }

    enum Action: Sendable {
        case onAppear
        case loadedLocal([ChatRoom])
        case loadedRemote([ChatRoom])
        case loadFailed(String)
        case roomTapped(ChatRoom)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case roomTapped(ChatRoom)
        }
    }

    @Dependency(\.chatClient) var chatClient
    @Dependency(\.chatLocalStore) var chatLocalStore

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                let currentUserId = KeychainHelper.load(forKey: "userId") ?? ""
                return .run { send in
                    let local = try await chatLocalStore.fetchRooms()
                    await send(.loadedLocal(local))

                    let remote = try await chatClient.getChatRooms()
                    if !remote.isEmpty {
                        try await chatLocalStore.upsertRooms(remote, currentUserId)
                    }
                    let merged = try await chatLocalStore.fetchRooms()
                    await send(.loadedRemote(merged))
                } catch: { error, send in
                    await send(.loadFailed(error.localizedDescription))
                }

            case .loadedLocal(let rooms):
                state.rooms = IdentifiedArray(uniqueElements: rooms)
                return .none

            case .loadedRemote(let rooms):
                state.isLoading = false
                state.rooms = IdentifiedArray(uniqueElements: rooms)
                return .none

            case .loadFailed(let message):
                state.isLoading = false
                state.errorMessage = message
                return .none

            case .roomTapped(let room):
                return .send(.delegate(.roomTapped(room)))

            case .delegate:
                return .none
            }
        }
    }
}
