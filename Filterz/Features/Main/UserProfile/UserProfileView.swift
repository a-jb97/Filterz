import SwiftUI
import ComposableArchitecture

struct UserProfileView: View {
    @Bindable var store: StoreOf<UserProfileFeature>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.profile == nil {
                    loadingState
                } else if let profile = store.profile {
                    profileContent(profile)
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.filterzBackground.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.filterzGray30)
                    }
                }
            }
        }
        .tint(.filterzAccent)
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

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(.filterzGray30)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("프로필을 불러오지 못했습니다")
                .font(.pretendard(14, weight: .regular))
                .foregroundColor(.filterzGray30)
            Button("다시 시도") {
                store.send(.retryTapped)
            }
            .font(.pretendard(14, weight: .semibold))
            .foregroundColor(.filterzAccent)
            Spacer()
        }
    }

    private func profileContent(_ profile: UserProfile) -> some View {
        ScrollView {
            VStack(spacing: 22) {
                profileImage(profile)
                    .padding(.top, 28)

                VStack(spacing: 14) {
                    if let name = profile.name, !name.isEmpty {
                        profileText(name, fontSize: 14, color: .filterzGray30)
                    }
                    profileText(profile.nick, fontSize: 24, color: .filterzGray30, weight: .semibold)
                    profileText(profile.introduction ?? "소개가 없습니다", fontSize: 15, color: .filterzGray30)

                    hashTagRow(profile.hashTags)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)

                filterSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 48)
        }
    }

    private func profileImage(_ profile: UserProfile) -> some View {
        ZStack {
            Circle()
                .fill(Color.filterzBackground)

            AuthenticatedImageView(path: profile.profileImagePath)
                .clipShape(Circle())

            if profile.profileImagePath == nil {
                Image(systemName: "person.fill")
                    .font(.system(size: 46, weight: .light))
                    .foregroundColor(.filterzGray30)
            }
        }
        .frame(width: 124, height: 124)
        .overlay(Circle().stroke(Color.filterzTranslucent, lineWidth: 1))
    }

    private func profileText(
        _ text: String,
        fontSize: CGFloat,
        color: Color,
        weight: Font.Weight = .regular
    ) -> some View {
        Text(text)
            .font(.pretendard(fontSize, weight: weight))
            .foregroundColor(color)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .frame(maxWidth: .infinity)
    }

    private func hashTagRow(_ hashTags: [String]) -> some View {
        UserProfileFlowLayout(spacing: 8) {
            if hashTags.isEmpty {
                Text("#해시태그 없음")
                    .font(.pretendard(13, weight: .regular))
                    .foregroundColor(.filterzGray30)
            } else {
                ForEach(hashTags, id: \.self) { tag in
                    Text("#\(displayHashTag(tag))")
                        .filterzTornTapeStyle(
                            font: .pretendard(13, weight: .medium),
                            foregroundColor: .filterzGray30,
                            horizontalPadding: 12,
                            verticalPadding: 7
                        )
                }
            }
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("제작한 필터")
                .font(.pretendard(18, weight: .semibold))
                .foregroundColor(.filterzGray30)
                .frame(maxWidth: .infinity, alignment: .leading)

            filterCategoryRow

            if store.isFiltersLoading && store.filters.isEmpty {
                ProgressView()
                    .tint(.filterzGray30)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
            } else if store.filters.isEmpty {
                Text("등록한 필터가 없습니다")
                    .font(.pretendard(14, weight: .regular))
                    .foregroundColor(.filterzGray30)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
            } else {
                FeedBlockGridView(
                    items: store.filters,
                    onItemTapped: { store.send(.filterTapped(id: $0)) },
                    onAuthorTapped: { _ in }
                )
                .padding(.horizontal, -20)

                if store.hasMoreFilters {
                    ProgressView()
                        .tint(.filterzGray30)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                        .onAppear { store.send(.loadMoreFilters) }
                }
            }
        }
        .padding(.top, 10)
    }

    private var filterCategoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryButton(title: "전체", isSelected: store.selectedCategory == nil) {
                    store.send(.filterCategorySelected(nil))
                }

                ForEach(FilterCategory.allCases, id: \.title) { category in
                    categoryButton(title: category.title, isSelected: store.selectedCategory == category) {
                        store.send(.filterCategorySelected(category))
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func categoryButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .filterzTornTapeStyle(
                    font: .pretendard(13, weight: .semibold),
                    foregroundColor: isSelected ? .filterzGray30 : .filterzAccent,
                    fillColor: isSelected ? .filterzClip : .filterzBackground,
                    strokeColor: isSelected ? nil : .filterzDeepSprout,
                    horizontalPadding: 13,
                    verticalPadding: 10
                )
        }
        .buttonStyle(.plain)
    }
}

private struct UserProfileFlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat) {
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        let rows = rows(for: subviews, maxWidth: maxWidth)
        let height = rows.reduce(CGFloat.zero) { partial, row in
            partial + row.height
        } + CGFloat(max(rows.count - 1, 0)) * spacing
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = rows(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.midX - row.width / 2
            for item in row.items {
                item.subview.place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if nextWidth > maxWidth, !current.items.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.append(subview: subview, size: size, spacing: spacing)
        }

        if !current.items.isEmpty {
            rows.append(current)
        }
        return rows
    }

    private struct Row {
        var items: [Item] = []
        var width: CGFloat = 0
        var height: CGFloat = 0

        mutating func append(subview: LayoutSubview, size: CGSize, spacing: CGFloat) {
            if !items.isEmpty {
                width += spacing
            }
            items.append(Item(subview: subview, size: size))
            width += size.width
            height = max(height, size.height)
        }
    }

    private struct Item {
        let subview: LayoutSubview
        let size: CGSize
    }
}
