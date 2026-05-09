import ComposableArchitecture

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var isCheckingSession: Bool = true
        var auth: AuthFeature.State? = nil
        var main: MainFeature.State? = nil
        var pendingChatPush: ChatPushPayload? = nil
    }

    enum Action: Sendable {
        case onAppear
        case sessionCheckResponse(Bool)
        case scenePhaseChanged(Bool)
        case chatPushReceived(ChatPushPayload)
        case chatPushTapped(ChatPushPayload)
        case auth(AuthFeature.Action)
        case main(MainFeature.Action)
    }

    @Dependency(\.authClient) var authClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.isCheckingSession, state.auth == nil, state.main == nil else {
                    return .none
                }
                state.isCheckingSession = true
                return .run { send in
                    async let isAuthenticated = authClient.checkSession()
                    async let minimumDelay: Void = try Task.sleep(for: .milliseconds(1500))
                    let (result, _) = try await (isAuthenticated, minimumDelay)
                    await send(.sessionCheckResponse(result))
                }

            case .sessionCheckResponse(true):
                state.isCheckingSession = false
                state.main = .init()
                state.auth = nil
                if let payload = state.pendingChatPush {
                    state.pendingChatPush = nil
                    return .send(.main(.chatPushTapped(payload)))
                }
                return .none

            case .sessionCheckResponse(false):
                state.isCheckingSession = false
                state.auth = .init()
                state.main = nil
                return .none

            case .scenePhaseChanged(let isActive):
                guard state.main != nil else { return .none }
                return .send(.main(.scenePhaseChanged(isActive)))

            case .auth(.delegate(.authenticationComplete)):
                state.auth = nil
                state.main = .init()
                if let payload = state.pendingChatPush {
                    state.pendingChatPush = nil
                    return .send(.main(.chatPushTapped(payload)))
                }
                return .none

            case .main(.delegate(.logoutCompleted)):
                state.main = nil
                state.auth = .init()
                return .none

            case .chatPushReceived(let payload):
                guard state.main != nil else { return .none }
                return .send(.main(.chatPushReceived(payload)))

            case .chatPushTapped(let payload):
                guard state.main != nil else {
                    state.pendingChatPush = payload
                    return .none
                }
                return .send(.main(.chatPushTapped(payload)))

            case .auth, .main:
                return .none
            }
        }
        .ifLet(\.auth, action: \.auth) { AuthFeature() }
        .ifLet(\.main, action: \.main) { MainFeature() }
    }
}
