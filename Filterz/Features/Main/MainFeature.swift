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
        var path: StackState<Path.State> = .init()
        var isOpeningDM: Bool = false
    }

    enum Action: Sendable {
        case tabSelected(Tab)
        case home(HomeFeature.Action)
        case feed(FeedFeature.Action)
        case upload(UploadFilterFeature.Action)
        case chatList(ChatListFeature.Action)
        case path(StackActionOf<Path>)
        case createChatRoomResponse(Result<ChatRoom, any Error>)
        case logoutTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case logoutCompleted
        }
    }

    @Dependency(\.chatClient) var chatClient

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
        Reduce { state, action in
            switch action {
            case .tabSelected(let tab):
                let returning = tab == .explore && state.selectedTab != .explore
                state.selectedTab = tab
                return returning ? .send(.upload(.reset)) : .none

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

            case .path(.element(_, .chatRoom(.delegate(.backTapped)))):
                state.path.removeLast()
                return .none

            case .home, .feed, .upload, .chatList, .path:
                return .none

            case .logoutTapped:
                return .send(.delegate(.logoutCompleted))

            case .delegate:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}

extension MainFeature.Path.State: Equatable {}
