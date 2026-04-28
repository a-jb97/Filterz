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

                        TopRankingCarouselView(items: store.topRankingItems)
                            .padding(.top, 8)

                        filterFeedHeader

                        switch store.viewMode {
                        case .block:
                            FeedBlockGridView(items: store.feedItems)
                                .padding(.top, 8)
                        case .list:
                            FeedListView(items: store.feedItems)
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
            Button {
            } label: {
                Image(systemName: "chevron.left")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 20)
                    .foregroundColor(.filterzGray60)
                    .padding(8)
            }
            .frame(width: 48, height: 48)

            Spacer()

            Text("FEED")
                .font(.mulgyeolBold(20))
                .foregroundColor(.filterzGray60)

            Spacer()

            Color.clear.frame(width: 48, height: 48)
        }
        .padding(.horizontal, 4)
        .frame(height: 56)
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
                .foregroundColor(isSelected ? .filterzGray45 : .filterzGray75)
                .padding(.horizontal, 17)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? Color.filterzBrightTurquoise : Color.filterzBlackTurquoise)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    isSelected ? Color.filterzDeepSprout : Color.clear,
                                    lineWidth: 1
                                )
                        )
                )
        }
    }
}
