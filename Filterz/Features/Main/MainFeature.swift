import ComposableArchitecture

@Reducer
struct MainFeature {

    enum Tab: Equatable, CaseIterable {
        case home, market, explore, chat, mypage
    }

    @Reducer
    enum Path {
        case filterDetail(FilterDetailFeature)
        case chatRoom(ChatRoomFeature)
    }

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .home
        var home: HomeFeature.State = .init()
        var feed: FeedFeature.State = .init()
        var upload: UploadFilterFeature.State = .init()
        var chatList: ChatListFeature.State = .init()
        var mypage: MyPageFeature.State = .init()
        var path: StackState<Path.State> = .init()
        var isOpeningDM: Bool = false
        var chatUnreadCount: Int = 0
        var currentChatRoomId: String? = nil
    }

    enum Action: Sendable {
        case tabSelected(Tab)
        case chatPushReceived(ChatPushPayload)
        case chatPushTapped(ChatPushPayload)
        case openChatFromPush(roomId: String)
        case openChatFromPushResponse(Result<ChatRoom, any Error>)
        case home(HomeFeature.Action)
        case feed(FeedFeature.Action)
        case upload(UploadFilterFeature.Action)
        case chatList(ChatListFeature.Action)
        case mypage(MyPageFeature.Action)
        case path(StackActionOf<Path>)
        case createChatRoomResponse(Result<ChatRoom, any Error>)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case logoutCompleted
        }
    }

    @Dependency(\.chatClient) var chatClient
    @Dependency(\.chatLocalStore) var chatLocalStore

    var body: some Reducer<State, Action> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Scope(state: \.feed, action: \.feed) {
            FeedFeature()
        }
        Scope(state: \.upload, action: \.upload) {
            UploadFilterFeature()
        }
        Scope(state: \.chatList, action: \.chatList) {
            ChatListFeature()
        }
        Scope(state: \.mypage, action: \.mypage) {
            MyPageFeature()
        }
        Reduce { state, action in
            switch action {
            case .tabSelected(let tab):
                let returning = tab == .explore && state.selectedTab != .explore
                state.selectedTab = tab
                return returning ? .send(.upload(.reset)) : .none

            case .chatPushReceived(let payload):
                state.chatUnreadCount = payload.unreadCount
                return .run { _ in
                    await PushNotificationBridge.setApplicationBadge(payload.unreadCount)
                }

            case .chatPushTapped(let payload):
                state.chatUnreadCount = payload.unreadCount
                return .merge(
                    .run { _ in
                        await PushNotificationBridge.setApplicationBadge(payload.unreadCount)
                    },
                    .send(.openChatFromPush(roomId: payload.roomId))
                )

            case .openChatFromPush(let roomId):
                state.selectedTab = .chat
                guard state.currentChatRoomId != roomId else { return .none }
                if let room = state.chatList.rooms[id: roomId] {
                    state.path.append(.chatRoom(.init(room: room)))
                    return .none
                }
                let currentUserId = KeychainHelper.load(forKey: "userId") ?? ""
                return .run { send in
                    do {
                        let dtos = try await chatClient.getChatRooms()
                        if !dtos.isEmpty {
                            try await chatLocalStore.upsertRooms(dtos, currentUserId)
                        }
                        let rooms = try await chatLocalStore.fetchRooms()
                        guard let room = rooms.first(where: { $0.roomId == roomId }) else {
                            throw NetworkError.notFound
                        }
                        await send(.openChatFromPushResponse(.success(room)))
                    } catch {
                        await send(.openChatFromPushResponse(.failure(error)))
                    }
                }

            case .openChatFromPushResponse(.success(let room)):
                state.chatList.rooms.updateOrAppend(room)
                guard state.currentChatRoomId != room.roomId else { return .none }
                state.path.append(.chatRoom(.init(room: room)))
                return .none

            case .openChatFromPushResponse(.failure):
                return .none

            case .home(.delegate(.filterTapped(let id))):
                state.path.append(.filterDetail(.init(filterId: id)))
                return .none

            case .home(.delegate(.categoryTapped(let category))):
                state.selectedTab = .market
                return .send(.feed(.categorySelected(category)))

            case .feed(.delegate(.filterTapped(let id))):
                state.path.append(.filterDetail(.init(filterId: id)))
                return .none

            case .path(.element(_, .filterDetail(.delegate(.backTapped)))):
                state.path.removeLast()
                return .none

            case .path(.element(_, .filterDetail(.delegate(.dmCreatorTapped(let creatorId))))):
                guard !state.isOpeningDM else { return .none }
                state.isOpeningDM = true
                return .run { send in
                    do {
                        let dto = try await chatClient.createChatRoom(creatorId)
                        let currentUserId = KeychainHelper.load(forKey: "userId") ?? ""
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
                state.isOpeningDM = false
                state.path.append(.chatRoom(.init(room: room)))
                return .none

            case .createChatRoomResponse(.failure):
                state.isOpeningDM = false
                return .none

            case .chatList(.delegate(.roomTapped(let room))):
                state.path.append(.chatRoom(.init(room: room)))
                return .none

            case .mypage(.delegate(.logoutCompleted)):
                return .send(.delegate(.logoutCompleted))

            case .path(.element(let id, .chatRoom(.onAppear))):
                guard case let .chatRoom(chatRoomState)? = state.path[id: id] else {
                    return .none
                }
                let roomId = chatRoomState.room.roomId
                state.currentChatRoomId = roomId
                return .run { _ in
                    await MainActor.run {
                        PushNotificationBridge.currentChatRoomId = roomId
                    }
                }

            case .path(.element(let id, .chatRoom(.onDisappear))):
                guard case let .chatRoom(chatRoomState)? = state.path[id: id],
                      state.currentChatRoomId == chatRoomState.room.roomId else {
                    return .none
                }
                state.currentChatRoomId = nil
                return .run { _ in
                    await MainActor.run {
                        PushNotificationBridge.currentChatRoomId = nil
                    }
                }

            case .path(.element(_, .chatRoom(.delegate(.backTapped)))):
                state.currentChatRoomId = nil
                state.path.removeLast()
                return .run { _ in
                    await MainActor.run {
                        PushNotificationBridge.currentChatRoomId = nil
                    }
                }

            case .home, .feed, .upload, .chatList, .mypage, .path:
                return .none

            case .delegate:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}

extension MainFeature.Path.State: Equatable {}
