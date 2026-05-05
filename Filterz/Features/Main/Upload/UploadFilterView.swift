// UploadFilterView.swift

import SwiftUI
import PhotosUI
import ComposableArchitecture

struct UploadFilterView: View {
    @Bindable var store: StoreOf<UploadFilterFeature>
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var displayImage: UIImage? = nil
    @State private var mapImage: UIImage? = nil
    @FocusState private var focusedField: FocusField?
    @State private var keyboardHeight: CGFloat = 0

    enum FocusField: Hashable {
        case filterName, description, price
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationHeader
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        filterNameSection
                            .id(FocusField.filterName)
                        categorySection
                        photoSection
                        descriptionSection
                            .id(FocusField.description)
                        priceSection
                            .id(FocusField.price)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 120)
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: keyboardHeight)
                }
                .onChange(of: focusedField) { _, field in
                    guard let field else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation { proxy.scrollTo(field, anchor: .bottom) }
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .simultaneousGesture(TapGesture().onEnded { focusedField = nil })
        .background(Color.filterzBlackBase.ignoresSafeArea())
        .onAppear {
            store.send(.onAppear)
            if displayImage == nil, let data = store.displayThumbnail {
                Task.detached(priority: .userInitiated) {
                    let image = UIImage(data: data)
                    await MainActor.run { displayImage = image }
                }
            }
            if mapImage == nil, let data = store.mapSnapshotData {
                Task.detached(priority: .userInitiated) {
                    let image = UIImage(data: data)
                    await MainActor.run { mapImage = image }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = frame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task.detached(priority: .userInitiated) {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                _ = await MainActor.run { store.send(.imageSelected(data)) }
            }
        }
        .onChange(of: store.displayThumbnail) { _, data in
            guard let data else { displayImage = nil; pickerItem = nil; return }
            Task.detached(priority: .userInitiated) {
                let image = UIImage(data: data)
                await MainActor.run { displayImage = image }
            }
        }
        .onChange(of: store.mapSnapshotData) { _, data in
            guard let data else { mapImage = nil; return }
            Task.detached(priority: .userInitiated) {
                let image = UIImage(data: data)
                await MainActor.run { mapImage = image }
            }
        }
        .alert("업로드 완료", isPresented: Binding(
            get: { store.isSaveSucceeded },
            set: { if !$0 { store.send(.successAlertDismissed) } }
        )) {
            Button("확인") { store.send(.successAlertDismissed) }
        } message: {
            Text("필터가 성공적으로 등록되었습니다.")
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

    // MARK: - Navigation Header

    private var navigationHeader: some View {
        HStack {
            if store.mode.isEdit {
                Button { store.send(.backTapped) } label: {
                    Image(systemName: "chevron.left")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 10, height: 18)
                        .foregroundStyle(Color.filterzGray60)
                        .padding(8)
                }
                .frame(width: 44, height: 44)
            }

            Text(store.mode.isEdit ? "필터 수정" : "필터 제작")
                .font(.filterzDisplay(24))
                .foregroundStyle(Color.filterzGray30)

            Spacer()

            Button { store.send(.saveTapped) } label: {
                if store.isUploading {
                    ProgressView()
                        .tint(Color.filterzGray30)
                        .frame(width: 44, height: 44)
                } else {
                    Image(systemName: store.mode.isEdit ? "checkmark" : "square.and.arrow.down")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.filterzGray30)
                        .frame(width: 44, height: 44)
                }
            }
            .disabled(store.isUploading)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color.filterzBlackBase)
    }

    // MARK: - 필터명

    private var filterNameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("필터명")
            TextField(
                "필터 이름을 입력해주세요.",
                text: $store.filterName.sending(\.filterNameChanged)
            )
            .focused($focusedField, equals: .filterName)
            .inputFieldStyle()
        }
    }

    // MARK: - 카테고리

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("카테고리")
            HStack(spacing: 8) {
                ForEach(UploadFilterFeature.categories, id: \.self) { category in
                    categoryChip(category)
                }
            }
        }
    }

    private func categoryChip(_ category: String) -> some View {
        let isSelected = store.selectedCategory == category
        return Button {
            store.send(.categorySelected(category))
        } label: {
            Text(category)
                .font(.filterzCaption())
                .foregroundStyle(isSelected ? Color.filterzBackground : Color.filterzGray30)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.filterzAccent : Color.filterzBlackAccent)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    isSelected ? Color.filterzAccent : Color.filterzDeepSprout,
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 대표 사진 등록

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("대표 사진 등록")
                Spacer()
                if store.selectedImageData != nil || store.existingImagePath != nil {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Text("수정하기")
                            .font(.filterzCaption())
                            .foregroundStyle(Color.filterzAccent)
                    }
                    .buttonStyle(.plain)
                }
            }

            if store.selectedImageData != nil || store.existingImagePath != nil {
                if let uiImage = displayImage {
                    filledPhotoArea(uiImage: uiImage)
                } else if let existingImagePath = store.existingImagePath {
                    filledRemotePhotoArea(path: existingImagePath)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.filterzSurface)
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .overlay(ProgressView().tint(Color.filterzGray60))
                }
            } else {
                emptyPhotoArea
            }
        }
    }

    private var emptyPhotoArea: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.filterzSurface)
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Color.filterzGray60)
            }
        }
        .buttonStyle(.plain)
    }

    private func filledPhotoArea(uiImage: UIImage) -> some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .overlay(
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .allowsHitTesting(false)
                )
                .clipped()
                .contentShape(Rectangle())

            if let meta = store.imageMetadata {
                metadataCard(meta)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func filledRemotePhotoArea(path: String) -> some View {
        VStack(spacing: 0) {
            AuthenticatedImageView(path: path)
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .clipped()
                .contentShape(Rectangle())

            if let meta = store.imageMetadata {
                metadataCard(meta)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func metadataLeftView(_ meta: ImageMetadata) -> some View {
        if let uiImage = mapImage {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if meta.latitude != nil {
            Color.filterzAccent
        } else {
            Image(systemName: "camera.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.filterzGray60)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.filterzAccent)
        }
    }

    private func metadataCard(_ meta: ImageMetadata) -> some View {
        HStack(alignment: .top, spacing: 12) {
            metadataLeftView(meta)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(meta.cameraModel ?? "카메라")
                        .font(.filterzCaption())
                        .foregroundStyle(Color.filterzGray30)
                    Spacer()
                    Text("EXIF")
                        .font(.filterzCaption())
                        .foregroundStyle(Color.filterzBackground)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.filterzAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                if let spec = meta.lensSpec {
                    Text(spec)
                        .font(.filterzCaption())
                        .foregroundStyle(Color.filterzGray60)
                }

                let sizeLine = [meta.megapixels, meta.resolution, meta.fileSize]
                    .compactMap { $0 }
                    .joined(separator: " · ")
                if !sizeLine.isEmpty {
                    Text(sizeLine)
                        .font(.filterzCaption())
                        .foregroundStyle(Color.filterzGray60)
                }

                if let address = meta.address {
                    Text(address)
                        .font(.filterzCaption())
                        .foregroundStyle(Color.filterzGray60)
                }

                if let dateStr = meta.dateTimeOriginal {
                    Text(dateStr)
                        .font(.filterzCaption())
                        .foregroundStyle(Color.filterzGray60)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.filterzBlackAccent)
    }

    // MARK: - 필터 소개

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("필터 소개")
            TextField(
                "이 필터에 대해 간단하게 소개해주세요.",
                text: $store.filterDescription.sending(\.filterDescriptionChanged)
            )
            .focused($focusedField, equals: .description)
            .inputFieldStyle()
        }
    }

    // MARK: - 판매 가격

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("판매 가격")
            HStack(spacing: 0) {
                TextField(
                    "1,000",
                    text: $store.price.sending(\.priceChanged)
                )
                .keyboardType(.numberPad)
                .font(.filterzBody())
                .foregroundStyle(Color.filterzGray30)
                .tint(Color.filterzGray30)
                .focused($focusedField, equals: .price)

                Text("원")
                    .font(.filterzBody())
                    .foregroundStyle(Color.filterzGray60)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.filterzSurface)
            )
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.filterzBody())
            .foregroundStyle(Color.filterzGray30)
    }
}

// MARK: - Input Field Style

private extension View {
    func inputFieldStyle() -> some View {
        self
            .font(.filterzBody())
            .foregroundStyle(Color.filterzGray30)
            .tint(Color.filterzGray30)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.filterzSurface)
            )
            .frame(maxWidth: .infinity)
    }
}
