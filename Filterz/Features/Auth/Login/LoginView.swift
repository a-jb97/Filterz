import SwiftUI
import ComposableArchitecture

struct LoginView: View {
    @Bindable var store: StoreOf<LoginFeature>

    var body: some View {
        ZStack {
            Color.filterzBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    logoSection
                        .padding(.top, 80)
                        .padding(.bottom, 48)

                    formSection
                        .padding(.horizontal, 24)

                    dividerSection
                        .padding(.vertical, 24)
                        .padding(.horizontal, 24)

                    socialSection
                        .padding(.horizontal, 24)

                    signUpLink
                        .padding(.top, 32)
                        .padding(.bottom, 48)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                TapGesture().onEnded {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            )

            if store.isLoading {
                loadingOverlay
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // MARK: - Logo

    private var logoSection: some View {
        VStack(spacing: 10) {
            (
                Text("FILTER")
                    .foregroundColor(.filterzTextPrimary)
                + Text("Z")
                    .foregroundColor(.filterzAccent)
            )
            .font(.system(size: 42, weight: .black))
            Text("나만의 필터를 발견하세요")
                .font(.filterzBody())
                .foregroundColor(.filterzTextSecondary)
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 16) {
            FilterzTextField(
                placeholder: "이메일",
                text: $store.email.sending(\.emailChanged),
                icon: "envelope",
                keyboardType: .emailAddress,
                autocapitalization: .never
            )

            FilterzSecureField(
                placeholder: "비밀번호",
                text: $store.password.sending(\.passwordChanged),
                isVisible: store.passwordVisible,
                onToggleVisibility: { store.send(.togglePasswordVisibility) },
                icon: "lock"
            )

            Button {
                store.send(.loginButtonTapped)
            } label: {
                Text("로그인")
            }
            .buttonStyle(CapsulePrimaryButtonStyle(isLoading: store.isLoading))
            .disabled(store.isLoading)
            .padding(.top, 8)
        }
    }

    // MARK: - Divider

    private var dividerSection: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(Color.filterzBorder)
                .frame(height: 1)
            Text("또는")
                .font(.filterzCaption())
                .foregroundColor(.filterzTextSecondary)
            Rectangle()
                .fill(Color.filterzBorder)
                .frame(height: 1)
        }
    }

    // MARK: - Social

    private var socialSection: some View {
        VStack(spacing: 12) {
            SocialLoginButton(provider: .kakao) {
                store.send(.kakaoLoginTapped)
            }
            SocialLoginButton(provider: .apple) {
                store.send(.appleLoginTapped)
            }
        }
    }

    // MARK: - SignUp Link

    private var signUpLink: some View {
        HStack(spacing: 4) {
            Text("계정이 없으신가요?")
                .font(.filterzBody())
                .foregroundColor(.filterzTextSecondary)
            Button {
                store.send(.navigateToSignUp)
            } label: {
                Text("회원가입")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.filterzAccent)
            }
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        Color.black.opacity(0.5)
            .ignoresSafeArea()
            .overlay(
                ProgressView()
                    .tint(.filterzAccent)
                    .scaleEffect(1.4)
            )
    }
}
