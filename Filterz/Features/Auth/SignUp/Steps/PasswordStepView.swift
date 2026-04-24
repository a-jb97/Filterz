import SwiftUI
import ComposableArchitecture

struct PasswordStepView: View {
    @Bindable var store: StoreOf<PasswordStepFeature>

    private var isNextEnabled: Bool {
        store.passwordRequirements.isValid && store.password == store.confirmPassword
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("비밀번호를 설정해주세요")
                    .font(.filterzHeadline())
                    .foregroundColor(.filterzTextPrimary)
                Text("아래 조건을 모두 충족해야 합니다")
                    .font(.filterzBody())
                    .foregroundColor(.filterzTextSecondary)
            }

            VStack(spacing: 16) {
                FilterzSecureField(
                    placeholder: "비밀번호",
                    text: $store.password.sending(\.passwordChanged),
                    isVisible: store.passwordVisible,
                    onToggleVisibility: { store.send(.togglePasswordVisibility) },
                    icon: "lock"
                )

                if !store.password.isEmpty {
                    PasswordRequirementsView(requirements: store.passwordRequirements)
                }

                FilterzSecureField(
                    placeholder: "비밀번호 확인",
                    text: $store.confirmPassword.sending(\.confirmPasswordChanged),
                    isVisible: store.confirmPasswordVisible,
                    onToggleVisibility: { store.send(.toggleConfirmPasswordVisibility) },
                    icon: "lock",
                    error: store.validationError
                )
            }

            Spacer()

            Button {
                store.send(.nextTapped)
            } label: {
                Text("다음")
            }
            .buttonStyle(CapsulePrimaryButtonStyle(isDisabled: !isNextEnabled))
            .disabled(!isNextEnabled)
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .padding(.bottom, 32)
    }
}

private struct PasswordRequirementsView: View {
    let requirements: AuthValidation.PasswordRequirements

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            requirementRow("8자 이상", requirements.hasMinLength)
            requirementRow("영문자 포함 (A-z)", requirements.hasLetter)
            requirementRow("숫자 포함 (0-9)", requirements.hasNumber)
            requirementRow("특수문자 포함 (@$!%*#?&)", requirements.hasSpecialChar)
        }
        .padding(.horizontal, 4)
    }

    private func requirementRow(_ label: String, _ isSatisfied: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isSatisfied ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSatisfied ? .filterzAccent : .filterzTextSecondary)
                .font(.system(size: 14))
            Text(label)
                .font(.filterzCaption())
                .foregroundColor(isSatisfied ? .filterzTextPrimary : .filterzTextSecondary)
        }
        .animation(.easeInOut(duration: 0.15), value: isSatisfied)
    }
}
