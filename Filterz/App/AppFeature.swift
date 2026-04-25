import ComposableArchitecture

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var isCheckingSession: Bool = true
        var auth: AuthFeature.State? = nil
        var main: MainFeature.State? = nil
    }

    enum Action: Sendable {
        case onAppear
        case sessionCheckResponse(Bool)
        case auth(AuthFeature.Action)
        case main(MainFeature.Action)
    }

    @Dependency(\.authClient) var authClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isCheckingSession = true
                return .run { send in
                    let isAuthenticated = await authClient.checkSession()
                    await send(.sessionCheckResponse(isAuthenticated))
                }

            case .sessionCheckResponse(true):
                state.isCheckingSession = false
                state.main = .init()
                state.auth = nil
                return .none

            case .sessionCheckResponse(false):
                state.isCheckingSession = false
                state.auth = .init()
                state.main = nil
                return .none

            case .auth(.delegate(.authenticationComplete)):
                state.auth = nil
                state.main = .init()
                return .none

            case .main(.delegate(.logoutCompleted)):
                state.main = nil
                state.auth = .init()
                return .none

            case .auth, .main:
                return .none
            }
        }
        .ifLet(\.auth, action: \.auth) { AuthFeature() }
        .ifLet(\.main, action: \.main) { MainFeature() }
    }
}
