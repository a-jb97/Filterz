import ComposableArchitecture

@Reducer
struct EmailStepFeature {
    @ObservableState
    struct State: Equatable {
        var email: String = ""
        var validationError: String? = nil
        var isCheckingDuplicate: Bool = false
    }

    enum Action: Sendable {
        case emailChanged(String)
        case nextTapped
        case emailCheckResponse(Result<Bool, AuthError>)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case nextTapped(email: String)
        }
    }

    @Dependency(\.authClient) var authClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .emailChanged(let text):
                state.email = text
                state.validationError = nil
                return .none

            case .nextTapped:
                guard AuthValidation.isValidEmail(state.email) else {
                    state.validationError = "올바른 이메일 형식을 입력해주세요."
                    return .none
                }
                state.isCheckingDuplicate = true
                return .run { [email = state.email] send in
                    await send(.emailCheckResponse(
                        Result { try await authClient.checkEmailDuplicate(email) }
                            .mapError { ($0 as? AuthError) ?? .unknown }
                    ))
                }

            case .emailCheckResponse(.success(true)):
                state.isCheckingDuplicate = false
                return .send(.delegate(.nextTapped(email: state.email)))

            case .emailCheckResponse(.success(false)):
                state.isCheckingDuplicate = false
                state.validationError = "이미 사용 중인 이메일입니다."
                return .none

            case .emailCheckResponse(.failure(let error)):
                state.isCheckingDuplicate = false
                state.validationError = error.errorDescription
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
