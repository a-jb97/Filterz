import SwiftUI
import ComposableArchitecture

struct NicknameStepView: View {
    @Bindable var store: StoreOf<NicknameStepFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("닉네임을 정해주세요")
                    .font(.filterzHeadline())
                    .foregroundColor(.filterzTextPrimary)
                Text("2~12자 이내로 입력해주세요")
                    .font(.filterzBody())
                    .foregroundColor(.filterzTextSecondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    FilterzTextField(
                        placeholder: "닉네임",
                        text: $store.nickname.sending(\.nicknameChanged),
                        icon: "person",
                        error: store.validationError
                    )
                }
                HStack {
                    Spacer()
                    Text("\(store.nickname.count) / 12")
                        .font(.filterzCaption())
                        .foregroundColor(.filterzTextSecondary)
                        .padding(.trailing, 4)
                }
            }

            Spacer()

            Button {
                store.send(.submitTapped)
            } label: {
                Text("완료")
            }
            .buttonStyle(CapsulePrimaryButtonStyle(
                isLoading: store.isCheckingDuplicate,
                isDisabled: !store.isSubmitEnabled
            ))
            .disabled(!store.isSubmitEnabled || store.isCheckingDuplicate)
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .padding(.bottom, 32)
    }
}
