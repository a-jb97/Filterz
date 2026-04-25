import SwiftUI
import ComposableArchitecture

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        Group {
            if store.isCheckingSession {
                splashView
            } else if let authStore = store.scope(state: \.auth, action: \.auth) {
                AuthView(store: authStore)
            } else if store.scope(state: \.main, action: \.main) != nil {
                // MainView는 추후 구현
                Text("메인 화면")
                    .foregroundColor(.filterzTextPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.filterzBackground)
            }
        }
        .onAppear { store.send(.onAppear) }
    }

    private var splashView: some View {
        ZStack {
            Color.filterzBackground.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("FILTERZ")
                    .font(.system(size: 42, weight: .black))
                    .foregroundColor(.filterzTextPrimary)
                ProgressView()
                    .tint(.filterzAccent)
            }
        }
    }
}
