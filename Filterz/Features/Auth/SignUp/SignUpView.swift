import SwiftUI
import ComposableArchitecture

struct SignUpView: View {
    @Bindable var store: StoreOf<SignUpFeature>

    var body: some View {
        ZStack(alignment: .top) {
            Color.filterzBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                StepProgressBar(totalSteps: 3, currentStep: stepIndex)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                ZStack {
                    if store.currentStep == .email {
                        EmailStepView(store: store.scope(state: \.emailStep, action: \.emailStep))
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    }
                    if store.currentStep == .password {
                        PasswordStepView(store: store.scope(state: \.passwordStep, action: \.passwordStep))
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    }
                    if store.currentStep == .nickname {
                        NicknameStepView(store: store.scope(state: \.nicknameStep, action: \.nicknameStep))
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: store.currentStep)
            }
        }
        .navigationBarHidden(true)
        .filterzSwipeBack {
            store.send(.backTapped)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var headerBar: some View {
        HStack {
            Button {
                store.send(.backTapped)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.filterzAccent)
            }
            Spacer()
            Text("회원가입")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.filterzTextPrimary)
            Spacer()
            Color.clear.frame(width: 24, height: 24)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var stepIndex: Int {
        switch store.currentStep {
        case .email:    return 0
        case .password: return 1
        case .nickname: return 2
        }
    }
}
