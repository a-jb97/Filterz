import ComposableArchitecture

@Reducer
struct NicknameStepFeature {
    @ObservableState
    struct State: Equatable {
        var nickname: String = ""
        var validationError: String? = nil
        var isCheckingDuplicate: Bool = false

        var isSubmitEnabled: Bool {
            nickname.count >= 2 && nickname.count <= 12
        }
    }

    enum Action: Sendable {
        case nicknameChanged(String)
        case submitTapped
        case nicknameCheckResponse(Result<Bool, AuthError>)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case submitTapped(nickname: String)
        }
    }

    @Dependency(\.authClient) var authClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .nicknameChanged(let text):
                state.nickname = String(text.prefix(12))
                state.validationError = nil
                return .none

            case .submitTapped:
                guard state.nickname.count >= 2 else {
                    state.validationError = "닉네임은 2자 이상이어야 합니다."
                    return .none
                }
                state.isCheckingDuplicate = true
                return .run { [nickname = state.nickname] send in
                    await send(.nicknameCheckResponse(
                        Result { try await authClient.checkNicknameDuplicate(nickname) }
                            .mapError { _ in AuthError.unknown }
                    ))
                }

            case .nicknameCheckResponse(.success(true)):
                state.isCheckingDuplicate = false
                return .send(.delegate(.submitTapped(nickname: state.nickname)))

            case .nicknameCheckResponse(.success(false)):
                state.isCheckingDuplicate = false
                state.validationError = "이미 사용 중인 닉네임입니다."
                return .none

            case .nicknameCheckResponse(.failure(let error)):
                state.isCheckingDuplicate = false
                state.validationError = error.errorDescription
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
