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
            } else if let mainStore = store.scope(state: \.main, action: \.main) {
                MainView(store: mainStore)
            }
        }
        .onAppear { store.send(.onAppear) }
        .task {
            if let payload = await PushNotificationBridge.consumePendingTappedPayload() {
                store.send(.chatPushTapped(payload))
            }
        }
        .task {
            for await notification in NotificationCenter.default.notifications(
                named: PushNotificationBridge.receivedNotification
            ) {
                guard let payload = notification.userInfo?[PushNotificationBridge.payloadKey] as? ChatPushPayload else {
                    continue
                }
                store.send(.chatPushReceived(payload))
            }
        }
        .task {
            for await notification in NotificationCenter.default.notifications(
                named: PushNotificationBridge.tappedNotification
            ) {
                guard let payload = notification.userInfo?[PushNotificationBridge.payloadKey] as? ChatPushPayload else {
                    continue
                }
                await PushNotificationBridge.clearPendingTappedPayload(payload)
                store.send(.chatPushTapped(payload))
            }
        }
    }

    private var splashView: some View {
        ZStack {
            Color.filterzBackground.ignoresSafeArea()
            (
                Text("FILTER")
                    .foregroundColor(.filterzTextPrimary)
                + Text("Z")
                    .foregroundColor(.filterzAccent)
            )
            .font(.custom("ClimateCrisisKR-1979", size: 42))
        }
    }
}
