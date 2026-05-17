import SwiftUI
import ComposableArchitecture

struct FeedView: View {
    @Bindable var store: StoreOf<FeedFeature>
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.filterzBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                FeedNavBarView(
                    isSearchPresented: store.isSearchPresented,
                    onVideoTapped: { store.send(.videoButtonTapped) },
                    onSearchTapped: { store.send(.searchButtonTapped) }
                )
                if store.isSearchPresented {
                    searchBar
                }
                SortButtonRowView(
                    sortMode: store.sortMode,
                    onSelect: { store.send(.sortChanged($0)) }
                )

                if store.isSearchPresented {
                    searchContent
                } else {
                    feedContent
                }
            }
        }
        .onAppear { store.send(.onAppear) }
        .onChange(of: store.isSearchPresented) { _, isPresented in
            isSearchFocused = isPresented
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.pretendard(16, weight: .bold))
            .foregroundColor(.filterzGray30)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
    }

    private var filterFeedHeader: some View {
        HStack {
            Text("필터 피드")
                .font(.pretendard(16, weight: .bold))
                .foregroundColor(.filterzGray30)

            if let category = store.selectedCategory {
                HStack(spacing: 4) {
                    Text(category.title)
                    Button {
                        store.send(.categorySelected(nil))
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.filterzAccent)
                    }
                }
                .filterzTornTapeStyle(
                    font: .pretendard(12, weight: .semibold),
                    foregroundColor: .filterzGray30,
                    horizontalPadding: 8,
                    verticalPadding: 3
                )
            }

            Spacer()

            Button {
                store.send(.viewModeToggled)
            } label: {
                Text(store.viewMode.title)
                    .font(.pretendard(13, weight: .medium))
                    .foregroundColor(.filterzAccent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var feedContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Top 10")
                    .padding(.bottom, 4)

                TopRankingCarouselView(items: store.topRankingItems) { id in
                    store.send(.topRankingItemTapped(id: id))
                } onAuthorTapped: { userId in
                    store.send(.authorProfileTapped(userId: userId))
                }
                .padding(.top, 8)

                filterFeedHeader

                switch store.viewMode {
                case .block:
                    FeedBlockGridView(items: store.feedItems) { id in
                        store.send(.feedItemTapped(id: id))
                    } onAuthorTapped: { userId in
                        store.send(.authorProfileTapped(userId: userId))
                    }
                    .padding(.top, 8)
                case .list:
                    FeedListView(items: store.feedItems) { id in
                        store.send(.feedItemTapped(id: id))
                    } onAuthorTapped: { userId in
                        store.send(.authorProfileTapped(userId: userId))
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 100)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.filterzGray30)

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

            if store.isSearchingUsers {
                ProgressView()
                    .tint(Color.filterzGray30)
                    .scaleEffect(0.8)
            } else if !store.searchText.isEmpty {
                Button {
                    store.send(.searchTextChanged(""))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.filterzGray30)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.filterzBackground)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background(Color.filterzBackground)
    }

    private var searchContent: some View {
        Group {
            if store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                searchEmptyText("닉네임을 검색해보세요")
            } else if let user = store.selectedSearchUser {
                selectedUserFilterList(user)
            } else if store.isSearchingUsers && store.searchUsers.isEmpty {
                Spacer()
                ProgressView().tint(.filterzGray30)
                Spacer()
            } else if store.searchUsers.isEmpty {
                searchEmptyText("검색 결과가 없습니다")
            } else {
                userSearchResults
            }
        }
    }

    private func searchEmptyText(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.pretendard(14, weight: .regular))
                .foregroundColor(.filterzGray30)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var userSearchResults: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(store.searchUsers) { user in
                    FeedSearchUserCell(user: user) {
                        store.send(.searchUserSelected(user))
                    }
                    Divider()
                        .background(Color.filterzTranslucent)
                        .padding(.leading, 76)
                }
            }
            .padding(.bottom, 100)
        }
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(keyboardDismissDragGesture)
    }

    private func selectedUserFilterList(_ user: FeedFeature.SearchUser) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text("\(user.nick)의 필터")
                        .font(.pretendard(16, weight: .bold))
                        .foregroundColor(.filterzGray30)

                    if let category = store.selectedCategory {
                        Text(category.title)
                            .filterzTornTapeStyle(
                                font: .pretendard(12, weight: .semibold),
                                foregroundColor: .filterzGray30,
                                horizontalPadding: 8,
                                verticalPadding: 3
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                if store.isLoadingUserFilters && store.searchedUserFilters.isEmpty {
                    ProgressView()
                        .tint(.filterzGray30)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if store.searchedUserFilters.isEmpty {
                    Text("등록한 필터가 없습니다")
                        .font(.pretendard(14, weight: .regular))
                        .foregroundColor(.filterzGray30)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else {
                    FeedListView(items: store.searchedUserFilters) { id in
                        store.send(.feedItemTapped(id: id))
                    } onAuthorTapped: { userId in
                        store.send(.authorProfileTapped(userId: userId))
                    }
                    .padding(.top, 8)

                    if store.hasMoreUserFilters {
                        ProgressView()
                            .tint(.filterzGray30)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .onAppear { store.send(.loadMoreUserFilters) }
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(keyboardDismissDragGesture)
    }

    private var keyboardDismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { _ in
                isSearchFocused = false
            }
    }
}

// MARK: - FeedNavBarView

private struct FeedNavBarView: View {
    let isSearchPresented: Bool
    let onVideoTapped: () -> Void
    let onSearchTapped: () -> Void

    var body: some View {
        HStack {
            Text("피드")
                .font(.filterzDisplay(24))
                .foregroundColor(.filterzGray30)
            Spacer()
            Button(action: onVideoTapped) {
                Image(systemName: "video")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.filterzAccent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button(action: onSearchTapped) {
                Image(systemName: isSearchPresented ? "xmark" : "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.filterzAccent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color.filterzBackground)
    }
}

private struct FeedSearchUserCell: View {
    let user: FeedFeature.SearchUser
    let onTapped: () -> Void

    var body: some View {
        Button(action: onTapped) {
            HStack(spacing: 12) {
                AuthenticatedImageView(path: user.profileImagePath)
                    .frame(width: 48, height: 48)
                    .background(Color.filterzBackground)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.filterzTranslucent, lineWidth: 1))

                Text(user.nick)
                    .font(.pretendard(15, weight: .semibold))
                    .foregroundColor(.filterzGray30)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.filterzGray30)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SortButtonRowView

private struct SortButtonRowView: View {
    let sortMode: FeedFeature.SortMode
    let onSelect: (FeedFeature.SortMode) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Spacer()
            ForEach(FeedFeature.SortMode.allCases, id: \.self) { mode in
                sortButton(for: mode)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 44)
    }

    private func sortButton(for mode: FeedFeature.SortMode) -> some View {
        let isSelected = sortMode == mode

        return Button {
            onSelect(mode)
        } label: {
            Text(mode.title)
                .filterzTornTapeStyle(
                    font: .pretendard(14, weight: isSelected ? .bold : .medium),
                    fillColor: isSelected ? .filterzClip : .filterzBackground,
                    strokeColor: isSelected ? nil : .filterzDeepSprout
                )
        }
        .buttonStyle(.plain)
    }
}
