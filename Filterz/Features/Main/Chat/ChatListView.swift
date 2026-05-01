import SwiftUI
import ComposableArchitecture

struct ChatListView: View {
    @Bindable var store: StoreOf<ChatListFeature>

    var body: some View {
        VStack(spacing: 0) {
            header

            if store.isLoading && store.rooms.isEmpty {
                Spacer()
                ProgressView().tint(.filterzGray45)
                Spacer()
            } else if store.rooms.isEmpty {
                Spacer()
                Text("아직 대화가 없습니다")
                    .font(.pretendard(14, weight: .regular))
                    .foregroundColor(.filterzGray60)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.rooms) { room in
                            Button { store.send(.roomTapped(room)) } label: {
                                ChatRoomCell(room: room)
                            }
                            .buttonStyle(.plain)
                            Divider()
                                .background(Color.filterzTranslucent)
                                .padding(.leading, 84)
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .background(Color.filterzBlackBase.ignoresSafeArea())
        .onAppear { store.send(.onAppear) }
    }

    private var header: some View {
        HStack {
            Text("Chat")
                .font(.filterzDisplay(24))
                .foregroundColor(.filterzGray30)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color.filterzBlackBase)
    }
}
