import SwiftUI
import ComposableArchitecture

struct FeedView: View {
    @Bindable var store: StoreOf<FeedFeature>

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.filterzBlackBase.ignoresSafeArea()

            VStack(spacing: 0) {
                FeedNavBarView()
                SortButtonRowView(
                    sortMode: store.sortMode,
                    onSelect: { store.send(.sortChanged($0)) }
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader("Top Ranking")

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
        }
        .onAppear { store.send(.onAppear) }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.pretendard(16, weight: .bold))
            .foregroundColor(.filterzGray60)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
    }

    private var filterFeedHeader: some View {
        HStack {
            Text("Filter Feed")
                .font(.pretendard(16, weight: .bold))
                .foregroundColor(.filterzGray60)

            if let category = store.selectedCategory {
                HStack(spacing: 4) {
                    Text(category.title)
                        .font(.pretendard(12, weight: .semibold))
                        .foregroundColor(.filterzAccent)
                    Button {
                        store.send(.categorySelected(nil))
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.filterzAccent)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.filterzBlackAccent)
                )
            }

            Spacer()

            Button {
                store.send(.viewModeToggled)
            } label: {
                Text(store.viewMode.title)
                    .font(.pretendard(16, weight: .medium))
                    .foregroundColor(.filterzGray75)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

// MARK: - FeedNavBarView

private struct FeedNavBarView: View {
    var body: some View {
        HStack {
            Text("피드")
                .font(.filterzDisplay(24))
                .foregroundColor(.filterzGray30)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color.filterzBlackBase)
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
                .font(.pretendard(14, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .filterzBackground : .filterzGray30)
                .padding(.horizontal, isSelected ? 17 : 12)
                .padding(.vertical, isSelected ? 5 : 7)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.filterzAccent : Color.filterzBlackAccent)
                        .overlay(
                            Capsule()
                                .stroke(
                                    Color.filterzDeepSprout,
                                    lineWidth: 1
                                )
                        )
                )
        }
    }
}
