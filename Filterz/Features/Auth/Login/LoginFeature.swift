import ComposableArchitecture
import Foundation

@Reducer
struct LoginFeature {
    @ObservableState
    struct State: Equatable {
        var email: String = ""
        var password: String = ""
        var passwordVisible: Bool = false
        var isLoading: Bool = false
        @Presents var alert: AlertState<Action.Alert>?
    }

    enum Action: Sendable {
        case emailChanged(String)
        case passwordChanged(String)
        case togglePasswordVisibility
        case loginButtonTapped
        case kakaoLoginTapped
        case appleLoginTapped
        case loginResponse(Result<AuthToken, AuthError>)
        case kakaoLoginResponse(Result<String, any Error>)
        case appleLoginResponse(Result<AppleCredential, any Error>)
        case navigateToSignUp
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        enum Alert: Equatable {}

        @CasePathable
        enum Delegate: Sendable {
            case loginSucceeded(AuthToken)
        }
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.kakaoAuthClient) var kakaoAuthClient
    @Dependency(\.appleAuthClient) var appleAuthClient

    func makeAlert(title: String, message: String?) -> AlertState<Action.Alert> {
        AlertState {
            TextState(title)
        } actions: {
            ButtonState(role: .cancel) { TextState("확인") }
        } message: {
            TextState(message ?? "오류가 발생했습니다.")
        }
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .emailChanged(let text):
                state.email = text
                return .none

            case .passwordChanged(let text):
                state.password = text
                return .none

            case .togglePasswordVisibility:
                state.passwordVisible.toggle()
                return .none

            case .loginButtonTapped:
                guard !state.email.isEmpty, !state.password.isEmpty else {
                    state.alert = makeAlert(title: "입력 오류", message: "이메일과 비밀번호를 입력해주세요.")
                    return .none
                }
                guard AuthValidation.isValidEmail(state.email) else {
                    state.alert = makeAlert(title: "입력 오류", message: "올바른 이메일 형식을 입력해주세요.")
                    return .none
                }
                state.isLoading = true
                return .run { [email = state.email, password = state.password] send in
                    await send(.loginResponse(
                        Result { try await authClient.emailLogin(email, password) }
                            .mapError { ($0 as? AuthError) ?? .unknown }
                    ))
                }

            case .kakaoLoginTapped:
                state.isLoading = true
                return .run { send in
                    await send(.kakaoLoginResponse(
                        Result { try await kakaoAuthClient.login() }
                    ))
                }

            case .appleLoginTapped:
                state.isLoading = true
                return .run { send in
                    await send(.appleLoginResponse(
                        Result { try await appleAuthClient.login() }
                    ))
                }

            case .loginResponse(.success(let token)):
                state.isLoading = false
                return .send(.delegate(.loginSucceeded(token)))

            case .loginResponse(.failure(let error)):
                state.isLoading = false
                state.alert = makeAlert(title: "로그인 실패", message:error.errorDescription)
                return .none

            case .kakaoLoginResponse(.success(let kakaoToken)):
                return .run { send in
                    await send(.loginResponse(
                        Result { try await authClient.socialLogin(.kakao, kakaoToken) }
                            .mapError { _ in AuthError.unknown }
                    ))
                }

            case .kakaoLoginResponse(.failure):
                state.isLoading = false
                state.alert = makeAlert(title: "로그인 실패", message:"카카오 로그인에 실패했습니다.")
                return .none

            case .appleLoginResponse(.success(let cred)):
                return .run { send in
                    await send(.loginResponse(
                        Result { try await authClient.socialLogin(.apple, cred.identityToken) }
                            .mapError { _ in AuthError.unknown }
                    ))
                }

            case .appleLoginResponse(.failure):
                state.isLoading = false
                state.alert = makeAlert(title: "로그인 실패", message:"Apple 로그인에 실패했습니다.")
                return .none

            case .navigateToSignUp, .delegate:
                return .none

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
