import ComposableArchitecture
import Foundation

@Reducer
struct ChatListFeature {

    nonisolated struct SearchUser: Equatable, Sendable, Identifiable {
        let userId: String
        let nick: String
        let profileImagePath: String?

        var id: String { userId }

        init(dto: UserInfoResponseDTO) {
            self.userId = dto.userID
            self.nick = dto.nick
            self.profileImagePath = dto.profileImage
        }
    }

    @ObservableState
    struct State: Equatable {
        var rooms: IdentifiedArrayOf<ChatRoom> = []
        var searchResults: IdentifiedArrayOf<SearchUser> = []
        var isLoading: Bool = false
        var isSearchPresented: Bool = false
        var isSearching: Bool = false
        var searchText: String = ""
        var creatingChatUserId: String? = nil
        var deletingRoomId: String? = nil
        var errorMessage: String? = nil
        @Presents var alert: AlertState<Action.Alert>?
    }

    enum Action: Sendable {
        case onAppear
        case loadedLocal([ChatRoom])
        case loadedRemote([ChatRoom])
        case loadFailed(String)
        case roomTapped(ChatRoom)
        case roomProfileTapped(ChatRoom)
        case searchButtonTapped
        case searchTextChanged(String)
        case searchResponse(Result<[SearchUser], any Error>)
        case searchUserProfileTapped(SearchUser)
        case searchUserTapped(SearchUser)
        case createChatRoomResponse(Result<ChatRoom, any Error>)
        case deleteButtonTapped(ChatRoom)
        case deleteConfirmed(roomId: String)
        case deleteResponse(Result<String, any Error>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        enum Alert: Equatable, Sendable {
            case confirmDelete(String)
        }

        @CasePathable
        enum Delegate: Sendable {
            case roomTapped(ChatRoom)
            case userProfileTapped(userId: String)
        }
    }

    @Dependency(\.chatClient) var chatClient
    @Dependency(\.chatLocalStore) var chatLocalStore
    @Dependency(\.userClient) var userClient
    @Dependency(\.continuousClock) var clock

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

            case .roomProfileTapped(let room):
                return .send(.delegate(.userProfileTapped(userId: room.opponentUserId)))

            case .deleteButtonTapped(let room):
                state.alert = AlertState {
                    TextState("채팅방 목록에서 삭제")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDelete(room.id)) {
                        TextState("삭제")
                    }
                    ButtonState(role: .cancel) {
                        TextState("취소")
                    }
                } message: {
                    TextState("\(room.opponentNick)님과의 채팅방을 목록에서 삭제하시겠습니까? 대화 내용은 유지됩니다.")
                }
                return .none

            case .alert(.presented(.confirmDelete(let roomId))):
                return .send(.deleteConfirmed(roomId: roomId))

            case .alert:
                return .none

            case .deleteConfirmed(let roomId):
                guard state.deletingRoomId == nil else { return .none }
                state.deletingRoomId = roomId
                state.errorMessage = nil
                return .run { send in
                    do {
                        try await chatLocalStore.hideRoom(roomId)
                        await send(.deleteResponse(.success(roomId)))
                    } catch {
                        await send(.deleteResponse(.failure(error)))
                    }
                }

            case .deleteResponse(.success(let roomId)):
                state.deletingRoomId = nil
                state.rooms.remove(id: roomId)
                return .none

            case .deleteResponse(.failure(let error)):
                state.deletingRoomId = nil
                state.errorMessage = error.localizedDescription
                state.alert = AlertState {
                    TextState("삭제 실패")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("확인")
                    }
                } message: {
                    TextState(error.localizedDescription)
                }
                return .none

            case .searchButtonTapped:
                state.isSearchPresented.toggle()
                state.errorMessage = nil
                if !state.isSearchPresented {
                    state.searchText = ""
                    state.searchResults.removeAll()
                    state.isSearching = false
                    return .cancel(id: "chatListSearch")
                }
                return .none

            case .searchTextChanged(let text):
                state.searchText = text
                state.errorMessage = nil
                let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else {
                    state.isSearching = false
                    state.searchResults.removeAll()
                    return .cancel(id: "chatListSearch")
                }
                state.isSearching = true
                return .run { send in
                    try await clock.sleep(for: .milliseconds(300))
                    let currentUserId = KeychainHelper.load(forKey: "userId") ?? ""
                    let users = try await userClient.searchUsers(query)
                        .filter { $0.userID != currentUserId }
                        .map(SearchUser.init(dto:))
                    await send(.searchResponse(.success(users)))
                } catch: { error, send in
                    guard !(error is CancellationError) else { return }
                    await send(.searchResponse(.failure(error)))
                }
                .cancellable(id: "chatListSearch", cancelInFlight: true)

            case .searchResponse(.success(let users)):
                state.isSearching = false
                state.searchResults = IdentifiedArray(uniqueElements: users)
                return .none

            case .searchResponse(.failure(let error)):
                state.isSearching = false
                state.searchResults.removeAll()
                state.errorMessage = error.localizedDescription
                return .none

            case .searchUserProfileTapped(let user):
                return .send(.delegate(.userProfileTapped(userId: user.userId)))

            case .searchUserTapped(let user):
                guard state.creatingChatUserId == nil else { return .none }
                state.creatingChatUserId = user.userId
                state.errorMessage = nil
                return .run { send in
                    do {
                        let dto = try await chatClient.createChatRoom(user.userId)
                        let currentUserId = KeychainHelper.load(forKey: "userId") ?? ""
                        try? await chatLocalStore.upsertRooms([dto], currentUserId)
                        try? await chatLocalStore.unhideRoom(dto.roomId)
                        if let room = ChatRoom(dto: dto, currentUserId: currentUserId) {
                            await send(.createChatRoomResponse(.success(room)))
                        } else {
                            await send(.createChatRoomResponse(.failure(NetworkError.decodingFailed)))
                        }
                    } catch {
                        await send(.createChatRoomResponse(.failure(error)))
                    }
                }

            case .createChatRoomResponse(.success(let room)):
                state.creatingChatUserId = nil
                state.isSearchPresented = false
                state.searchText = ""
                state.searchResults.removeAll()
                state.rooms.updateOrAppend(room)
                return .send(.delegate(.roomTapped(room)))

            case .createChatRoomResponse(.failure(let error)):
                state.creatingChatUserId = nil
                state.errorMessage = error.localizedDescription
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
