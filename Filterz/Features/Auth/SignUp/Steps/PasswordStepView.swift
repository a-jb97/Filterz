import SwiftUI
import ComposableArchitecture

struct PasswordStepView: View {
    @Bindable var store: StoreOf<PasswordStepFeature>

    private var passwordStrength: PasswordStrength {
        if store.password.count < 8 { return .weak }
        if store.password.count < 12 { return .medium }
        return .strong
    }

    private var isNextEnabled: Bool {
        store.password.count >= 8 && store.password == store.confirmPassword
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("비밀번호를 설정해주세요")
                    .font(.filterzHeadline())
                    .foregroundColor(.filterzTextPrimary)
                Text("8자 이상의 비밀번호를 입력해주세요")
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

                FilterzSecureField(
                    placeholder: "비밀번호 확인",
                    text: $store.confirmPassword.sending(\.confirmPasswordChanged),
                    isVisible: store.confirmPasswordVisible,
                    onToggleVisibility: { store.send(.toggleConfirmPasswordVisibility) },
                    icon: "lock",
                    error: store.validationError
                )

                PasswordStrengthBar(strength: passwordStrength)
                    .opacity(store.password.isEmpty ? 0 : 1)
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

private struct PasswordStrengthBar: View {
    let strength: PasswordStrength

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color(for: index))
                    .frame(height: 3)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: strength)
    }

    private func color(for index: Int) -> Color {
        switch (strength, index) {
        case (.weak, 0):       return .filterzError
        case (.medium, 0...1): return Color(hex: "#F0A500")
        case (.strong, _):     return .filterzAccent
        default:               return .filterzBorder
        }
    }
}
