import SwiftUI
import ComposableArchitecture

struct ChatListView: View {
    @Bindable var store: StoreOf<ChatListFeature>
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            if store.isSearchPresented {
                searchBar
            }

            if store.isSearchPresented {
                searchResults
            } else if store.rooms.isEmpty {
                emptyRoomState
            } else {
                roomList
            }
        }
        .background(Color.filterzBlackBase.ignoresSafeArea())
        .onAppear { store.send(.onAppear) }
        .onChange(of: store.isSearchPresented) { _, isPresented in
            isSearchFocused = isPresented
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var header: some View {
        HStack {
            Text("Chat")
                .font(.filterzDisplay(24))
                .foregroundColor(.filterzGray30)
            Spacer()
            Button {
                store.send(.searchButtonTapped)
            } label: {
                Image(systemName: store.isSearchPresented ? "xmark" : "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.filterzGray30)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color.filterzBlackBase)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.filterzGray60)

            TextField(
                "닉네임 검색",
                text: $store.searchText.sending(\.searchTextChanged)
            )
            .font(.pretendard(14, weight: .regular))
            .foregroundStyle(Color.filterzGray30)
            .tint(Color.filterzGray30)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($isSearchFocused)

            if store.isSearching {
                ProgressView()
                    .tint(Color.filterzGray60)
                    .scaleEffect(0.8)
            } else if !store.searchText.isEmpty {
                Button {
                    store.send(.searchTextChanged(""))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.filterzGray75)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.filterzSurface)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background(Color.filterzBlackBase)
    }

    private var emptyRoomState: some View {
        Group {
            if store.isLoading {
                Spacer()
                ProgressView().tint(.filterzGray45)
                Spacer()
            } else {
                Spacer()
                Text("아직 대화가 없습니다")
                    .font(.pretendard(14, weight: .regular))
                    .foregroundColor(.filterzGray60)
                Spacer()
            }
        }
    }

    private var roomList: some View {
        List {
            ForEach(store.rooms) { room in
                VStack(spacing: 0) {
                    Button { store.send(.roomTapped(room)) } label: {
                        ChatRoomCell(room: room)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.deletingRoomId == room.id)

                    Divider()
                        .background(Color.filterzTranslucent)
                        .padding(.leading, 84)
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.filterzBlackBase)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        store.send(.deleteButtonTapped(room))
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                    .disabled(store.deletingRoomId != nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.filterzBlackBase)
        .contentMargins(.bottom, 100, for: .scrollContent)
    }

    private var searchResults: some View {
        Group {
            if store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Spacer()
                Text("닉네임을 검색해보세요")
                    .font(.pretendard(14, weight: .regular))
                    .foregroundColor(.filterzGray60)
                Spacer()
            } else if store.isSearching && store.searchResults.isEmpty {
                Spacer()
                ProgressView().tint(.filterzGray45)
                Spacer()
            } else if store.searchResults.isEmpty {
                Spacer()
                Text("검색 결과가 없습니다")
                    .font(.pretendard(14, weight: .regular))
                    .foregroundColor(.filterzGray60)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.searchResults) { user in
                            Button {
                                store.send(.searchUserTapped(user))
                            } label: {
                                SearchUserCell(
                                    user: user,
                                    isLoading: store.creatingChatUserId == user.userId
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(store.creatingChatUserId != nil)
                            Divider()
                                .background(Color.filterzTranslucent)
                                .padding(.leading, 76)
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
    }
}

private struct SearchUserCell: View {
    let user: ChatListFeature.SearchUser
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 12) {
            AuthenticatedImageView(path: user.profileImagePath)
                .frame(width: 48, height: 48)
                .background(Color.filterzBlackTurquoise)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.filterzTranslucent, lineWidth: 1))

            Text(user.nick)
                .font(.pretendard(15, weight: .semibold))
                .foregroundColor(.filterzGray30)
                .lineLimit(1)

            Spacer(minLength: 12)

            if isLoading {
                ProgressView()
                    .tint(Color.filterzGray60)
                    .scaleEffect(0.85)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
