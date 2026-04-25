import SwiftUI
import ComposableArchitecture

struct AuthView: View {
    @Bindable var store: StoreOf<AuthFeature>

    var body: some View {
        NavigationStack {
            LoginView(store: store.scope(state: \.login, action: \.login))
                .navigationDestination(
                    item: $store.scope(state: \.signUp, action: \.signUp)
                ) { signUpStore in
                    SignUpView(store: signUpStore)
                }
        }
        .tint(.filterzAccent)
    }
}
