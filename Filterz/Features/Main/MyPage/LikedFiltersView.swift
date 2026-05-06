import SwiftUI
import ComposableArchitecture

struct LikedFiltersView: View {
    @Bindable var store: StoreOf<LikedFiltersFeature>

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    categoryRow

                    if store.isLoading && store.items.isEmpty {
                        ProgressView()
                            .tint(.filterzGray45)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    } else if store.items.isEmpty {
                        Text("좋아요한 필터가 없습니다")
                            .font(.pretendard(14, weight: .regular))
                            .foregroundColor(.filterzGray75)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    } else {
                        FeedListView(
                            items: store.items,
                            onItemTapped: { store.send(.filterTapped(id: $0)) },
                            onAuthorTapped: { _ in }
                        )
                        .padding(.horizontal, -20)

                        if store.hasMore {
                            ProgressView()
                                .tint(.filterzGray45)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .onAppear { store.send(.loadMore) }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 100)
            }
        }
        .background(Color.filterzBlackBase.ignoresSafeArea())
        .filterzSwipeBack {
            store.send(.backTapped)
        }
        .onAppear { store.send(.onAppear) }
        .alert("오류", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.send(.errorDismissed) } }
        )) {
            Button("확인") { store.send(.errorDismissed) }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button {
                store.send(.backTapped)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.filterzGray30)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("좋아요한 필터")
                .font(.filterzDisplay(24))
                .foregroundColor(.filterzGray30)

            Spacer()
        }
        .padding(.horizontal, 6)
        .frame(height: 56)
        .background(Color.filterzBlackBase)
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryButton(title: "전체", isSelected: store.selectedCategory == nil) {
                    store.send(.categorySelected(nil))
                }

                ForEach(FilterCategory.allCases, id: \.title) { category in
                    categoryButton(title: category.title, isSelected: store.selectedCategory == category) {
                        store.send(.categorySelected(category))
                    }
                }
            }
        }
    }

    private func categoryButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.pretendard(13, weight: .semibold))
                .foregroundColor(isSelected ? .filterzBlackBase : .filterzGray60)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Color.filterzAccent : Color.filterzBlackAccent)
                )
        }
        .buttonStyle(.plain)
    }
}
