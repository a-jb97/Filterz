import ComposableArchitecture

@Reducer
struct MainFeature {

    enum Tab: Equatable, CaseIterable {
        case home, market, explore, chat, mypage
    }

    @Reducer
    enum Path {
        case filterDetail(FilterDetailFeature)
        case likedFilters(LikedFiltersFeature)
        case uploadFilter(UploadFilterFeature)
        case filterMaker(FilterMakerFeature)
        case chatRoom(ChatRoomFeature)
        case videoList(VideoListFeature)
        case videoPlayer(VideoPlayerFeature)
        case settings(SettingsFeature)
    }

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .home
        var home: HomeFeature.State = .init()
        var feed: FeedFeature.State = .init()
        var filterManagement: FilterManagementFeature.State = .init()
        var chatList: ChatListFeature.State = .init()
        var mypage: MyPageFeature.State = .init()
        var path: StackState<Path.State> = .init()
        @Presents var userProfile: UserProfileFeature.State?
        var isOpeningDM: Bool = false
        var chatUnreadCount: Int = 0
        var currentChatRoomId: String? = nil
    }

    enum Action: Sendable {
        case onAppear
        case badgeSyncedOnLaunch(Int)
        case tabSelected(Tab)
        case chatPushReceived(ChatPushPayload)
        case chatPushTapped(ChatPushPayload)
        case openChatFromPush(roomId: String)
        case openChatFromPushResponse(Result<ChatRoom, any Error>)
        case scenePhaseChanged(Bool)
        case home(HomeFeature.Action)
        case feed(FeedFeature.Action)
        case filterManagement(FilterManagementFeature.Action)
        case chatList(ChatListFeature.Action)
        case mypage(MyPageFeature.Action)
        case path(StackActionOf<Path>)
        case userProfile(PresentationAction<UserProfileFeature.Action>)
        case userProfileRequested(userId: String)
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
        Scope(state: \.filterManagement, action: \.filterManagement) {
            FilterManagementFeature()
        }
        Scope(state: \.chatList, action: \.chatList) {
            ChatListFeature()
        }
        Scope(state: \.mypage, action: \.mypage) {
            MyPageFeature()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                let initialLoad = Effect<Action>.run { send in
                    let currentUserId = KeychainHelper.load(forKey: "userId") ?? ""
                    guard let rooms = try? await chatLocalStore.fetchRooms(currentUserId) else { return }
                    let total = rooms.reduce(0) { $0 + $1.unreadCount }
                    await send(.badgeSyncedOnLaunch(total))
                }
                // Chat tab: ChatListFeature.onAppear가 로컬+원격 로드를 직접 처리
                guard state.selectedTab != .chat else { return initialLoad }
                return .merge(
                    initialLoad,
                    .send(.chatList(.refreshRooms)),
                    badgePollingEffect()
                )

            case .badgeSyncedOnLaunch(let total):
                state.chatUnreadCount = total
                return .run { _ in
                    await PushNotificationBridge.setApplicationBadge(total)
                }

            case .tabSelected(let tab):
                state.selectedTab = tab
                if tab == .chat {
                    return .cancel(id: "mainBadgePolling")
                }
                return badgePollingEffect()

            case .chatPushReceived(let payload):
                state.chatUnreadCount = payload.unreadCount
                var effects: [Effect<Action>] = [
                    .run { _ in
                        await PushNotificationBridge.setApplicationBadge(payload.unreadCount)
                    }
                ]
                if state.currentChatRoomId != payload.roomId {
                    effects.append(.send(.chatList(.chatPushReceived(payload))))
                }
                return .merge(effects)

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
                    state.chatList.rooms[id: roomId]?.unreadCount = 0
                    state.path.append(.chatRoom(.init(room: room)))
                    return .send(.chatList(.roomRead(roomId: roomId)))
                }
                let currentUserId = KeychainHelper.load(forKey: "userId") ?? ""
                return .run { send in
                    do {
                        let dtos = try await chatClient.getChatRooms()
                        if !dtos.isEmpty {
                            try await chatLocalStore.upsertRooms(dtos, currentUserId)
                        }
                        let rooms = try await chatLocalStore.fetchRooms(currentUserId)
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
                state.chatList.rooms[id: room.roomId]?.unreadCount = 0
                guard state.currentChatRoomId != room.roomId else {
                    return .send(.chatList(.roomRead(roomId: room.roomId)))
                }
                state.path.append(.chatRoom(.init(room: room)))
                return .send(.chatList(.roomRead(roomId: room.roomId)))

            case .openChatFromPushResponse(.failure):
                return .none

            case .scenePhaseChanged(let isActive):
                guard let current = currentChatRoomState(state) else { return .none }
                if isActive {
                    state.currentChatRoomId = current.roomId
                    return .run { _ in
                        await MainActor.run {
                            PushNotificationBridge.currentChatRoomId = current.roomId
                        }
                    }
                }
                state.currentChatRoomId = nil
                return .merge(
                    markLastSeenEffect(roomId: current.roomId, message: current.lastMessage),
                    .run { _ in
                        await MainActor.run {
                            PushNotificationBridge.currentChatRoomId = nil
                        }
                    }
                )

            case .home(.delegate(.filterTapped(let id))):
                state.path.append(.filterDetail(.init(filterId: id)))
                return .none

            case .home(.delegate(.categoryTapped(let category))):
                state.selectedTab = .market
                return .send(.feed(.categorySelected(category)))

            case .home(.delegate(.userProfileTapped(let userId))):
                return presentUserProfile(&state, userId: userId)

            case .feed(.delegate(.filterTapped(let id))):
                state.path.append(.filterDetail(.init(filterId: id)))
                return .none

            case .feed(.delegate(.userProfileTapped(let userId))):
                return presentUserProfile(&state, userId: userId)

            case .feed(.delegate(.videoListRequested)):
                state.path.append(.videoList(.init()))
                return .none

            case .filterManagement(.delegate(.uploadRequested)):
                state.path.append(.uploadFilter(.init(showsBackButton: true)))
                return .none

            case .filterManagement(.delegate(.filterDetailRequested(let id))):
                state.path.append(.filterDetail(.init(filterId: id)))
                return .none

            case .path(.element(let id, .filterDetail(.delegate(.backTapped)))):
                if let detail = state.path[id: id, case: \.filterDetail]?.detail {
                    updateFilterManagementLike(
                        &state,
                        filterId: detail.id,
                        isLiked: detail.isLiked,
                        likeCount: detail.likeCount
                    )
                }
                state.path.removeLast()
                return .none

            case .path(.element(_, .filterDetail(.delegate(.userProfileTapped(let userId))))):
                return presentUserProfile(&state, userId: userId)

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

            case .path(.element(let id, .filterDetail(.likeTapped))):
                guard let detail = state.path[id: id, case: \.filterDetail]?.detail else {
                    return .none
                }
                let isLiked = !detail.isLiked
                let likeCount = detail.likeCount + (detail.isLiked ? -1 : 1)
                updateFilterManagementLike(
                    &state,
                    filterId: detail.id,
                    isLiked: isLiked,
                    likeCount: likeCount
                )
                return .none

            case .path(.element(let id, .filterDetail(.likeResponse(.failure)))):
                guard let detail = state.path[id: id, case: \.filterDetail]?.detail else {
                    return .none
                }
                let isLiked = !detail.isLiked
                let likeCount = detail.likeCount + (detail.isLiked ? -1 : 1)
                updateFilterManagementLike(
                    &state,
                    filterId: detail.id,
                    isLiked: isLiked,
                    likeCount: likeCount
                )
                return .none

            case .path(.element(let id, .filterDetail(.likeResponse(.success)))):
                guard let detail = state.path[id: id, case: \.filterDetail]?.detail else {
                    return .none
                }
                updateFilterManagementLike(
                    &state,
                    filterId: detail.id,
                    isLiked: detail.isLiked,
                    likeCount: detail.likeCount
                )
                return .none

            case .path(.element(_, .filterDetail(.delegate(.editFilterRequested(let detail))))):
                state.path.append(.uploadFilter(.init(editing: detail)))
                return .none

            case .path(.element(_, .likedFilters(.delegate(.backTapped)))):
                state.path.removeLast()
                return .none

            case .path(.element(_, .likedFilters(.delegate(.filterTapped(let id))))):
                state.path.append(.filterDetail(.init(filterId: id)))
                return .none

            case .path(.element(let id, .filterDetail(.delegate(.filterDeleted)))):
                state.path.pop(from: id)
                return .none

            case .path(.element(let id, .uploadFilter(.delegate(.backTapped)))):
                state.path.pop(from: id)
                return .none

            case .path(.element(_, .uploadFilter(.delegate(.makeFilterRequested(let source, let values))))):
                state.path.append(.filterMaker(.init(source: source, values: values)))
                return .none

            case .path(.element(let id, .uploadFilter(.delegate(.editCompleted(let dto))))):
                let ids = Array(state.path.ids)
                if let index = ids.firstIndex(of: id), index > 0 {
                    let previousId = ids[index - 1]
                    let currentUserId = state.path[id: previousId, case: \.filterDetail]?.currentUserId ?? ""
                    state.path[id: previousId, case: \.filterDetail]?.detail = FilterDetail(dto: dto, currentUserId: currentUserId)
                }
                state.path.pop(from: id)
                return .none

            case .path(.element(let id, .filterMaker(.delegate(.saved(let values))))):
                let ids = Array(state.path.ids)
                if let index = ids.firstIndex(of: id), index > 0 {
                    let previousId = ids[index - 1]
                    state.path.pop(from: id)
                    guard state.path[id: previousId, case: \.uploadFilter] != nil else {
                        return .none
                    }
                    return .send(.path(.element(
                        id: previousId,
                        action: .uploadFilter(.filterValuesUpdated(values))
                    )))
                } else {
                    state.path.pop(from: id)
                    return .none
                }

            case .path(.element(let id, .filterMaker(.delegate(.backTapped)))):
                state.path.pop(from: id)
                return .none

            case .chatList(.delegate(.roomTapped(let room))):
                state.chatList.rooms[id: room.roomId]?.unreadCount = 0
                state.path.append(.chatRoom(.init(room: room)))
                return .send(.chatList(.roomRead(roomId: room.roomId)))

            case .chatList(.delegate(.userProfileTapped(let userId))):
                return presentUserProfile(&state, userId: userId)

            case .mypage(.delegate(.filterTapped(let id))):
                state.path.append(.filterDetail(.init(filterId: id)))
                return .none

            case .mypage(.delegate(.likedFiltersRequested)):
                state.path.append(.likedFilters(.init()))
                return .none

            case .mypage(.delegate(.settingsRequested)):
                state.path.append(.settings(SettingsFeature.State()))
                return .none

            case .mypage(.delegate(.logoutCompleted)):
                return .send(.delegate(.logoutCompleted))

            case .path(.element(let id, .chatRoom(.onAppear))):
                guard case let .chatRoom(chatRoomState)? = state.path[id: id] else {
                    return .none
                }
                let roomId = chatRoomState.room.roomId
                state.currentChatRoomId = roomId
                state.chatList.rooms[id: roomId]?.unreadCount = 0
                return .merge(
                    .send(.chatList(.roomRead(roomId: roomId))),
                    .run { _ in
                        await MainActor.run {
                            PushNotificationBridge.currentChatRoomId = roomId
                        }
                    }
                )

            case .path(.element(let id, .chatRoom(.onDisappear))):
                guard case let .chatRoom(chatRoomState)? = state.path[id: id],
                      state.currentChatRoomId == chatRoomState.room.roomId else {
                    return .none
                }
                let lastMessage = chatRoomState.messages.last
                let roomId = chatRoomState.room.roomId
                state.currentChatRoomId = nil
                return .merge(
                    markLastSeenEffect(roomId: roomId, message: lastMessage),
                    .run { _ in
                        await MainActor.run {
                            PushNotificationBridge.currentChatRoomId = nil
                        }
                    }
                )

            case .path(.element(let id, .chatRoom(.delegate(.backTapped)))):
                let lastSeen: (roomId: String, message: ChatMessage?)?
                if case let .chatRoom(chatRoomState)? = state.path[id: id] {
                    lastSeen = (chatRoomState.room.roomId, chatRoomState.messages.last)
                } else {
                    lastSeen = nil
                }
                state.currentChatRoomId = nil
                state.path.removeLast()
                return .merge(
                    lastSeen.map { markLastSeenEffect(roomId: $0.roomId, message: $0.message) } ?? .none,
                    .run { _ in
                        await MainActor.run {
                            PushNotificationBridge.currentChatRoomId = nil
                        }
                    }
                )

            case .path(.element(_, .chatRoom(.delegate(.userProfileTapped(let userId))))):
                return presentUserProfile(&state, userId: userId)

            case .path(.element(_, .videoList(.delegate(.backTapped)))):
                state.path.removeLast()
                return .none

            case .path(.element(_, .videoList(.delegate(.playVideoRequested(let video, let stream))))):
                state.path.append(.videoPlayer(.init(video: video, stream: stream)))
                return .none

            case .path(.element(_, .videoPlayer(.delegate(.backTapped)))):
                state.path.removeLast()
                return .none

            case .userProfileRequested(let userId):
                return presentUserProfile(&state, userId: userId)

            case .userProfile(.presented(.delegate(.filterTapped(let id)))):
                state.userProfile = nil
                state.path.append(.filterDetail(.init(filterId: id)))
                return .none

            case .chatList(.loadedLocal(_)),
                 .chatList(.loadedRemote(_)),
                 .chatList(.refreshedAfterPush(_)),
                 .chatList(.roomRead(roomId: _)),
                 .chatList(.deleteResponse(.success(_))):
                let total = state.chatList.rooms.reduce(0) { $0 + $1.unreadCount }
                state.chatUnreadCount = total
                return .run { _ in
                    await PushNotificationBridge.setApplicationBadge(total)
                }

            case .home, .feed, .filterManagement, .chatList, .mypage, .path, .userProfile:
                return .none

            case .delegate:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$userProfile, action: \.userProfile) {
            UserProfileFeature()
        }
    }

    private func badgePollingEffect() -> Effect<Action> {
        .run { send in
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(30))
                await send(.chatList(.refreshRooms))
            }
        }
        .cancellable(id: "mainBadgePolling", cancelInFlight: true)
    }

    private func presentUserProfile(_ state: inout State, userId: String) -> Effect<Action> {
        guard !userId.isEmpty else { return .none }
        let currentUserId = KeychainHelper.load(forKey: "userId") ?? ""
        guard userId != currentUserId else { return .none }
        state.userProfile = .init(userId: userId)
        return .none
    }

    private func markLastSeenEffect(roomId: String, message: ChatMessage?) -> Effect<Action> {
        guard let message else { return .none }
        return .run { _ in
            try? await chatLocalStore.markLastSeen(
                roomId,
                message.chatId,
                message.createdAt
            )
        }
    }

    private func currentChatRoomState(_ state: State) -> (roomId: String, lastMessage: ChatMessage?)? {
        for id in state.path.ids.reversed() {
            if let chatRoomState = state.path[id: id, case: \.chatRoom] {
                return (chatRoomState.room.roomId, chatRoomState.messages.last)
            }
        }
        return nil
    }

    private func updateFilterManagementLike(
        _ state: inout State,
        filterId: String,
        isLiked: Bool,
        likeCount: Int
    ) {
        guard let index = state.filterManagement.items.firstIndex(where: { $0.id == filterId }) else {
            return
        }
        state.filterManagement.items[index] = state.filterManagement.items[index].updatingLike(
            isLiked: isLiked,
            likeCount: likeCount
        )
    }
}

extension MainFeature.Path.State: Equatable {}
