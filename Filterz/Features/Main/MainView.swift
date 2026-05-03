import SwiftUI
import ComposableArchitecture

struct MainView: View {
    @Bindable var store: StoreOf<MainFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ZStack(alignment: .bottom) {
                tabContent
                CustomTabBarView(
                    selectedTab: $store.selectedTab.sending(\.tabSelected),
                    chatUnreadCount: store.chatUnreadCount
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationBarHidden(true)
        } destination: { pathStore in
            switch pathStore.case {
            case .filterDetail(let detailStore):
                FilterDetailView(store: detailStore)
                    .navigationBarHidden(true)
            case .chatRoom(let chatStore):
                ChatRoomView(store: chatStore)
                    .navigationBarHidden(true)
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch store.selectedTab {
        case .home:
            HomeView(store: store.scope(state: \.home, action: \.home))
        case .market:
            FeedView(store: store.scope(state: \.feed, action: \.feed))
        case .explore:
            UploadFilterView(store: store.scope(state: \.upload, action: \.upload))
        case .chat:
            ChatListView(store: store.scope(state: \.chatList, action: \.chatList))
        case .mypage:
            Color.filterzBlackBase.ignoresSafeArea()
        }
    }
}

// MARK: - Custom Tab Bar

private struct CustomTabBarView: View {
    @Binding var selectedTab: MainFeature.Tab
    let chatUnreadCount: Int

    var body: some View {
        HStack(spacing: 32) {
            ForEach(MainFeature.Tab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .frame(width: 350, height: 68)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 34)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 34)
                    .stroke(Color.filterzTranslucent, lineWidth: 1)
            }
        )
    }

    private func tabButton(for tab: MainFeature.Tab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: tab.icon(isSelected: isSelected))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(isSelected ? .filterzGray30 : .filterzGray75)
                    .shadow(
                        color: isSelected ? Color.white.opacity(0.15) : .clear,
                        radius: 2, x: 0, y: 3
                    )

                if tab == .chat, chatUnreadCount > 0 {
                    Text(badgeText(chatUnreadCount))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(minWidth: 18, minHeight: 18)
                        .padding(.horizontal, chatUnreadCount > 9 ? 4 : 0)
                        .background(Capsule().fill(Color.filterzAccent))
                        .offset(x: 9, y: -8)
                }
            }
            .frame(width: 44, height: 44)
        }
    }

    private func badgeText(_ count: Int) -> String {
        count > 99 ? "99+" : "\(count)"
    }
}

private extension MainFeature.Tab {
    func icon(isSelected: Bool) -> String {
        switch self {
        case .home:      return isSelected ? "house.fill" : "house"
        case .market:    return "square.grid.2x2"
        case .explore:   return "sparkles"
        case .chat:      return isSelected ? "message.fill" : "message"
        case .mypage:    return isSelected ? "person.fill" : "person"
        }
    }
}
