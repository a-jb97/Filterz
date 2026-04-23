import ComposableArchitecture
import Foundation

enum SignUpStep: Equatable {
    case email, password, nickname
}

@Reducer
struct SignUpFeature {
    @ObservableState
    struct State: Equatable {
        var currentStep: SignUpStep = .email
        var email: String = ""
        var password: String = ""
        var isLoading: Bool = false
        @Presents var alert: AlertState<Action.Alert>?

        var emailStep: EmailStepFeature.State = .init()
        var passwordStep: PasswordStepFeature.State = .init()
        var nicknameStep: NicknameStepFeature.State = .init()
    }

    enum Action: Sendable {
        case emailStep(EmailStepFeature.Action)
        case passwordStep(PasswordStepFeature.Action)
        case nicknameStep(NicknameStepFeature.Action)
        case backTapped
        case signUpResponse(Result<AuthToken, AuthError>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        enum Alert: Equatable {}

        @CasePathable
        enum Delegate: Sendable {
            case signUpSucceeded(AuthToken)
            case dismissTapped
        }
    }

    @Dependency(\.authClient) var authClient

    var body: some Reducer<State, Action> {
        Scope(state: \.emailStep, action: \.emailStep) { EmailStepFeature() }
        Scope(state: \.passwordStep, action: \.passwordStep) { PasswordStepFeature() }
        Scope(state: \.nicknameStep, action: \.nicknameStep) { NicknameStepFeature() }

        Reduce { state, action in
            switch action {
            case .emailStep(.delegate(.nextTapped(let email))):
                state.email = email
                state.currentStep = .password
                return .none

            case .passwordStep(.delegate(.nextTapped(let password))):
                state.password = password
                state.currentStep = .nickname
                return .none

            case .nicknameStep(.delegate(.submitTapped(let nickname))):
                state.isLoading = true
                return .run { [email = state.email, password = state.password] send in
                    await send(.signUpResponse(
                        Result {
                            try await authClient.signUp(email, password, nickname)
                        }.mapError { _ in AuthError.unknown }
                    ))
                }

            case .backTapped:
                switch state.currentStep {
                case .email:    return .send(.delegate(.dismissTapped))
                case .password: state.currentStep = .email
                case .nickname: state.currentStep = .password
                }
                return .none

            case .signUpResponse(.success(let token)):
                state.isLoading = false
                return .send(.delegate(.signUpSucceeded(token)))

            case .signUpResponse(.failure(let error)):
                state.isLoading = false
                state.alert = AlertState {
                    TextState("회원가입 실패")
                } actions: {
                    ButtonState(role: .cancel) { TextState("확인") }
                } message: {
                    TextState(error.errorDescription ?? "오류가 발생했습니다.")
                }
                return .none

            case .alert, .emailStep, .passwordStep, .nicknameStep, .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
