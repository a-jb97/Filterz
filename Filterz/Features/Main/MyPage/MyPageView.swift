import SwiftUI
import PhotosUI
import ComposableArchitecture

struct MyPageView: View {
    @Bindable var store: StoreOf<MyPageFeature>

    var body: some View {
        VStack(spacing: 0) {
            header

            Group {
                if store.isLoading && store.profile == nil {
                    loadingState
                } else if let profile = store.profile {
                    profileContent(profile)
                } else {
                    emptyState
                }
            }
        }
        .background(Color.filterzBlackBase.ignoresSafeArea())
        .onAppear { store.send(.onAppear) }
        .sheet(isPresented: $store.isEditPresented.sending(\.editPresentationChanged)) {
            ProfileEditSheet(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert("로그아웃", isPresented: $store.isLogoutConfirmationPresented.sending(\.logoutConfirmationChanged)) {
            Button("취소", role: .cancel) { }
            Button("로그아웃", role: .destructive) {
                store.send(.logoutConfirmed)
            }
        } message: {
            Text("정말 로그아웃하시겠습니까?")
        }
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
        HStack {
            Text("마이 페이지")
                .font(.filterzDisplay(24))
                .foregroundColor(.filterzGray30)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color.filterzBlackBase)
    }

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(.filterzGray45)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("프로필을 불러오지 못했습니다")
                .font(.pretendard(14, weight: .regular))
                .foregroundColor(.filterzGray60)
            Button("다시 시도") {
                store.send(.onAppear)
            }
            .font(.pretendard(14, weight: .semibold))
            .foregroundColor(.filterzAccent)
            Spacer()
        }
    }

    private func profileContent(_ profile: MyProfile) -> some View {
        ScrollView {
            VStack(spacing: 22) {
                profileImage(profile)
                    .padding(.top, 28)

                Button {
                    store.send(.editButtonTapped)
                } label: {
                    Text("프로필 수정")
                        .font(.pretendard(14, weight: .semibold))
                        .foregroundColor(.filterzGray30)
                        .padding(.horizontal, 18)
                        .frame(height: 38)
                        .background(
                            Capsule()
                                .fill(Color.filterzSurface)
                                .overlay(Capsule().stroke(Color.filterzBorder, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)

                VStack(spacing: 14) {
                    profileText(profile.email, fontSize: 14, color: .filterzGray60)
                    profileText(profile.nick, fontSize: 24, color: .filterzGray30, weight: .semibold)
                    profileText(profile.introduction ?? "소개가 없습니다", fontSize: 15, color: .filterzGray60)

                    hashTagRow(profile.hashTags)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)

                Button {
                    store.send(.logoutTapped)
                } label: {
                    Text("로그아웃")
                }
                .buttonStyle(CapsulePrimaryButtonStyle(isLoading: store.isLoggingOut))
                .disabled(store.isLoggingOut)
                .padding(.horizontal, 20)
                .padding(.top, 10)

                filterSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }

    private func profileImage(_ profile: MyProfile) -> some View {
        ZStack {
            Circle()
                .fill(Color.filterzBlackAccent)

            AuthenticatedImageView(path: profile.profileImagePath)
                .clipShape(Circle())

            if profile.profileImagePath == nil {
                Image(systemName: "person.fill")
                    .font(.system(size: 46, weight: .light))
                    .foregroundColor(.filterzGray75)
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
        FlowLayout(spacing: 8) {
            if hashTags.isEmpty {
                Text("#해시태그 없음")
                    .font(.pretendard(13, weight: .regular))
                    .foregroundColor(.filterzGray75)
            } else {
                ForEach(hashTags, id: \.self) { tag in
                    Text("#\(displayHashTag(tag))")
                        .font(.pretendard(13, weight: .medium))
                        .foregroundColor(.filterzGray30)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.filterzBlackAccent))
                        .overlay(Capsule().stroke(Color.filterzDeepSprout, lineWidth: 1))
                }
            }
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("내가 제작한 필터")
                .font(.pretendard(18, weight: .semibold))
                .foregroundColor(.filterzGray30)
                .frame(maxWidth: .infinity, alignment: .leading)

            filterCategoryRow

            if store.isFiltersLoading && store.filters.isEmpty {
                ProgressView()
                    .tint(.filterzGray45)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
            } else if store.filters.isEmpty {
                Text("등록한 필터가 없습니다")
                    .font(.pretendard(14, weight: .regular))
                    .foregroundColor(.filterzGray75)
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
                        .tint(.filterzGray45)
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

private struct ProfileEditSheet: View {
    @Bindable var store: StoreOf<MyPageFeature>
    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var previewImage: UIImage? = nil
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case nick, introduction, hashTags
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    imageSection
                    textFields
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.filterzBlackBase.ignoresSafeArea())
            .navigationTitle("프로필 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                    .foregroundStyle(Color.filterzGray60)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.send(.saveTapped)
                    } label: {
                        if store.isSaving {
                            ProgressView()
                                .tint(Color.filterzAccent)
                        } else {
                            Text("저장")
                                .font(.pretendard(15, weight: .semibold))
                        }
                    }
                    .disabled(store.isSaving)
                    .foregroundStyle(Color.filterzAccent)
                }
            }
        }
        .tint(.filterzAccent)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                let image = UIImage(data: data)
                await MainActor.run {
                    previewImage = image
                    store.send(.editImageSelected(data))
                }
            }
        }
        .onChange(of: store.editImageData) { _, data in
            guard let data else {
                previewImage = nil
                pickerItem = nil
                return
            }
            previewImage = UIImage(data: data)
        }
    }

    private var imageSection: some View {
        VStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.filterzBlackAccent)

                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    AuthenticatedImageView(path: store.profile?.profileImagePath)
                        .clipShape(Circle())
                    if store.profile?.profileImagePath == nil {
                        Image(systemName: "person.fill")
                            .font(.system(size: 42, weight: .light))
                            .foregroundColor(.filterzGray75)
                    }
                }
            }
            .frame(width: 112, height: 112)
            .overlay(Circle().stroke(Color.filterzTranslucent, lineWidth: 1))

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("사진 변경", systemImage: "photo")
                    .font(.pretendard(14, weight: .semibold))
                    .foregroundColor(.filterzAccent)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var textFields: some View {
        VStack(alignment: .leading, spacing: 18) {
            editFieldLabel("닉네임")
            TextField("닉네임", text: $store.editNick.sending(\.editNickChanged))
                .profileInputStyle()
                .focused($focusedField, equals: .nick)

            editFieldLabel("소개")
            TextEditor(text: $store.editIntroduction.sending(\.editIntroductionChanged))
                .font(.pretendard(15, weight: .regular))
                .foregroundColor(.filterzGray30)
                .tint(.filterzAccent)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.filterzSurface)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.filterzBorder, lineWidth: 1))
                )
                .focused($focusedField, equals: .introduction)

            editFieldLabel("해시태그")
            TextField("예: 감성 필름 풍경", text: $store.editHashTagsText.sending(\.editHashTagsTextChanged))
                .profileInputStyle()
                .focused($focusedField, equals: .hashTags)

            Text("공백 또는 쉼표로 구분해 입력하세요.")
                .font(.filterzCaption())
                .foregroundColor(.filterzGray75)
        }
    }

    private func editFieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.pretendard(13, weight: .semibold))
            .foregroundColor(.filterzGray60)
    }
}

private extension View {
    func profileInputStyle() -> some View {
        self
            .font(.pretendard(15, weight: .regular))
            .foregroundColor(.filterzGray30)
            .tint(.filterzAccent)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.filterzSurface)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.filterzBorder, lineWidth: 1))
            )
    }
}

private struct FlowLayout: Layout {
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
