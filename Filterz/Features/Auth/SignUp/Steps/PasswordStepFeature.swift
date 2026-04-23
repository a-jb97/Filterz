import ComposableArchitecture

enum PasswordStrength: Equatable {
    case weak, medium, strong
}

@Reducer
struct PasswordStepFeature {
    @ObservableState
    struct State: Equatable {
        var password: String = ""
        var confirmPassword: String = ""
        var passwordVisible: Bool = false
        var confirmPasswordVisible: Bool = false
        var validationError: String? = nil
    }

    enum Action: Sendable {
        case passwordChanged(String)
        case confirmPasswordChanged(String)
        case togglePasswordVisibility
        case toggleConfirmPasswordVisibility
        case nextTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case nextTapped(password: String)
        }
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .passwordChanged(let text):
                state.password = text
                state.validationError = nil
                return .none

            case .confirmPasswordChanged(let text):
                state.confirmPassword = text
                state.validationError = nil
                return .none

            case .togglePasswordVisibility:
                state.passwordVisible.toggle()
                return .none

            case .toggleConfirmPasswordVisibility:
                state.confirmPasswordVisible.toggle()
                return .none

            case .nextTapped:
                if state.password.count < 8 {
                    state.validationError = "비밀번호는 8자 이상이어야 합니다."
                    return .none
                }
                if state.password != state.confirmPassword {
                    state.validationError = "비밀번호가 일치하지 않습니다."
                    return .none
                }
                return .send(.delegate(.nextTapped(password: state.password)))

            case .delegate:
                return .none
            }
        }
    }
}
