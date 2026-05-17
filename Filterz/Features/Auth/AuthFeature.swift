import Foundation
import ComposableArchitecture

@Reducer
struct AuthFeature {
    @ObservableState
    struct State: Equatable {
        var login: LoginFeature.State = .init()
        @Presents var signUp: SignUpFeature.State?
    }

    enum Action: Sendable {
        case login(LoginFeature.Action)
        case signUp(PresentationAction<SignUpFeature.Action>)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case authenticationComplete(AuthToken)
        }
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.login, action: \.login) { LoginFeature() }

        Reduce { state, action in
            switch action {
            case .login(.navigateToSignUp):
                state.signUp = .init()
                return .none

            case .login(.delegate(.loginSucceeded(let token))):
                return .send(.delegate(.authenticationComplete(token)))

            case .signUp(.presented(.delegate(.signUpSucceeded(let token)))):
                state.signUp = nil
                return .send(.delegate(.authenticationComplete(token)))

            case .signUp(.presented(.delegate(.dismissTapped))):
                state.signUp = nil
                return .none

            case .login, .signUp, .delegate:
                return .none
            }
        }
        .ifLet(\.$signUp, action: \.signUp) { SignUpFeature() }
    }
}
