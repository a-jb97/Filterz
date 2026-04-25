import SwiftUI
import ComposableArchitecture

struct EmailStepView: View {
    @Bindable var store: StoreOf<EmailStepFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("이메일을 입력해주세요")
                    .font(.filterzHeadline())
                    .foregroundColor(.filterzTextPrimary)
                Text("로그인에 사용할 이메일을 입력해주세요")
                    .font(.filterzBody())
                    .foregroundColor(.filterzTextSecondary)
            }

            FilterzTextField(
                placeholder: "이메일",
                text: $store.email.sending(\.emailChanged),
                icon: "envelope",
                error: store.validationError,
                keyboardType: .emailAddress,
                autocapitalization: .never
            )

            Spacer()

            Button {
                store.send(.nextTapped)
            } label: {
                Text("다음")
            }
            .buttonStyle(CapsulePrimaryButtonStyle(
                isLoading: store.isCheckingDuplicate,
                isDisabled: store.email.isEmpty
            ))
            .disabled(store.email.isEmpty || store.isCheckingDuplicate)
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .padding(.bottom, 32)
    }
}
