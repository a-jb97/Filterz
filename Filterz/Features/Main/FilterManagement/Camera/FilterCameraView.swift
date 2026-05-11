import ComposableArchitecture
import SwiftUI

struct FilterCameraView: View {
    let filters: [PurchasedFilterItem]
    let onDismiss: () -> Void

    @StateObject private var camera = LiveFilterCameraController()
    @Dependency(\.photoLibraryClient) private var photoLibraryClient
    @State private var selectedFilterID: String?
    @State private var isFilterPickerPresented = false
    @State private var visibleFilterIDs = Set<String>()
    @State private var statusMessage: String?
    @State private var capturedPhotoData: Data?
    @State private var capturedPhotoOrientation: CameraDeviceOrientation = .portrait

    private var selectedFilter: PurchasedFilterItem? {
        filters.first { $0.id == selectedFilterID }
    }

    private let controlBarWidth: CGFloat = 320

    var body: some View {
        ZStack {
            Color.filterzBlackBase.ignoresSafeArea()

            cameraPreview

            if let capturedPhotoData {
                capturedPhotoPreview(capturedPhotoData)
            } else {
                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    zoomControls
                        .padding(.bottom, 16)
                    modePicker
                        .padding(.bottom, 18)
                    bottomBar
                }
            }

            if isFilterPickerPresented && capturedPhotoData == nil {
                filterPicker
            }

            if let statusMessage {
                statusToast(statusMessage)
            }
        }
        .task {
            camera.setSelectedFilter(selectedFilter)
            camera.start(filters: filters)
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: selectedFilterID) { _, _ in
            camera.setSelectedFilter(selectedFilter)
        }
        .onChange(of: isFilterPickerPresented) { _, isPresented in
            camera.setFilterSheetVisible(isPresented)
        }
        .onChange(of: visibleFilterIDs) { _, ids in
            camera.setVisiblePreviewIDs(ids)
        }
        .alert("카메라 오류", isPresented: Binding(
            get: { camera.errorMessage != nil },
            set: { if !$0 { camera.errorMessage = nil } }
        )) {
            Button("확인") { camera.errorMessage = nil }
        } message: {
            Text(camera.errorMessage ?? "")
        }
    }

    private var cameraPreview: some View {
        ZStack {
            if let image = camera.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(Color.filterzAccent)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.filterzGray30)
                    .rotationEffect(controlRotation)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.42)))
            }
            .buttonStyle(.plain)

            Spacer()

            if let selectedFilter {
                Text(selectedFilter.title)
                    .font(.filterzCaption())
                    .foregroundStyle(Color.filterzGray30)
                    .lineLimit(1)
                    .rotationEffect(controlRotation)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Capsule().fill(Color.black.opacity(0.42)))
            }
        }
        .frame(maxWidth: controlBarWidth)
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }

    private func capturedPhotoPreview(_ data: Data) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = previewImage(from: data, orientation: capturedPhotoOrientation) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Button {
                        capturedPhotoData = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.filterzGray30)
                            .rotationEffect(controlRotation)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.black.opacity(0.42)))
                    }
                    .buttonStyle(.plain)
                    .disabled(camera.isSaving)

                    Spacer()

                    Button {
                        saveCapturedPhoto(data)
                    } label: {
                        Group {
                            if camera.isSaving {
                                ProgressView()
                                    .tint(Color.filterzBackground)
                            } else {
                                Text("저장")
                                    .font(.filterzCaption())
                                    .foregroundStyle(Color.filterzBackground)
                            }
                        }
                        .rotationEffect(controlRotation)
                        .padding(.horizontal, 16)
                        .frame(minWidth: 58, minHeight: 38)
                        .background(Capsule().fill(camera.isSaving ? Color.filterzGray60 : Color.filterzAccent))
                    }
                    .buttonStyle(.plain)
                    .disabled(camera.isSaving)
                }
                .frame(maxWidth: controlBarWidth)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

                Spacer()
            }
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 8) {
            ForEach(camera.supportedZoomOptions) { option in
                Button {
                    camera.zoomTapped(option)
                } label: {
                    Text(zoomLabel(option.displayFactor))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(camera.selectedZoomOption == option ? Color.filterzBackground : Color.filterzGray30)
                        .rotationEffect(controlRotation)
                        .frame(width: 42, height: 32)
                        .background(
                            Capsule()
                                .fill(camera.selectedZoomOption == option ? Color.filterzAccent : Color.black.opacity(0.48))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.black.opacity(0.28)))
        .disabled(camera.isRecording || camera.isSaving)
    }

    private var modePicker: some View {
        HStack(spacing: 6) {
            modeButton("사진", mode: .photo)
            modeButton("동영상", mode: .video)
        }
        .padding(4)
        .background(Capsule().fill(Color.black.opacity(0.34)))
    }

    private func modeButton(_ title: String, mode: LiveFilterCameraController.CaptureMode) -> some View {
        Button {
            camera.switchMode(mode)
        } label: {
            Text(title)
                .font(.pretendard(13, weight: .bold))
                .foregroundStyle(camera.mode == mode ? Color.filterzBackground : Color.filterzGray30)
                .frame(width: 72, height: 32)
                .background(
                    Capsule().fill(camera.mode == mode ? Color.filterzAccent : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(camera.isRecording)
    }

    private var bottomBar: some View {
        HStack {
            Button {
                isFilterPickerPresented = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.42))
                    if let selectedFilter, let path = selectedFilter.imageURL {
                        AuthenticatedImageView(path: path, contentMode: .fill)
                            .frame(width: 58, height: 58)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "camera.filters")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(Color.filterzGray30)
                            .rotationEffect(controlRotation)
                    }
                }
                .frame(width: 64, height: 64)
            }
            .buttonStyle(.plain)
            .disabled(camera.isRecording)

            Spacer()

            Button {
                captureTapped()
            } label: {
                ZStack {
                    Circle()
                        .stroke(camera.mode == .video ? Color.red : Color.filterzGray30, lineWidth: 4)
                        .frame(width: 78, height: 78)

                    if camera.isSaving {
                        ProgressView()
                            .tint(Color.filterzBackground)
                            .rotationEffect(controlRotation)
                            .frame(width: 62, height: 62)
                            .background(Circle().fill(Color.filterzGray60))
                    } else if camera.mode == .video && camera.isRecording {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red)
                            .frame(width: 34, height: 34)
                    } else {
                        Circle()
                            .fill(camera.mode == .video ? Color.red : Color.filterzGray30)
                            .frame(width: 62, height: 62)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(camera.isSaving || !camera.isRunning)

            Spacer()

            Button {
                camera.switchCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.filterzGray30)
                    .rotationEffect(controlRotation)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Color.black.opacity(0.42)))
            }
            .buttonStyle(.plain)
            .disabled(camera.isRecording || camera.isSaving)
        }
        .frame(maxWidth: controlBarWidth)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 34)
    }

    private var filterPicker: some View {
        VStack {
            Spacer()

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("필터 선택")
                        .font(.filterzDisplay(20))
                        .foregroundStyle(Color.filterzGray30)

                    Spacer()

                    Button {
                        isFilterPickerPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.filterzGray30)
                            .rotationEffect(controlRotation)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)

                if filters.isEmpty {
                    Text("사용할 수 있는 필터가 없습니다")
                        .font(.pretendard(14, weight: .regular))
                        .foregroundStyle(Color.filterzGray75)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            neutralFilterCard

                            ForEach(filters) { filter in
                                filterCard(filter)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(height: 184)
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 28)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var neutralFilterCard: some View {
        Button {
            selectedFilterID = nil
            isFilterPickerPresented = false
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    if let image = camera.previewImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.filterzBlackAccent
                    }
                }
                .frame(width: 104, height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(selectionBorder(isSelected: selectedFilterID == nil))

                Text("Original")
                    .font(.pretendard(12, weight: .bold))
                    .foregroundStyle(Color.filterzGray30)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private func filterCard(_ filter: PurchasedFilterItem) -> some View {
        Button {
            selectedFilterID = filter.id
            isFilterPickerPresented = false
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    if let image = camera.filterPreviewImages[filter.id] {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.filterzBlackAccent
                        ProgressView()
                            .tint(Color.filterzAccent)
                    }
                }
                .frame(width: 104, height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(selectionBorder(isSelected: selectedFilterID == filter.id))

                Text(filter.title)
                    .font(.pretendard(12, weight: .bold))
                    .foregroundStyle(Color.filterzGray30)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: 104, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            visibleFilterIDs.insert(filter.id)
        }
        .onDisappear {
            visibleFilterIDs.remove(filter.id)
        }
    }

    private func selectionBorder(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(isSelected ? Color.filterzAccent : Color.clear, lineWidth: 3)
    }

    private func statusToast(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.filterzCaption())
                .foregroundStyle(Color.filterzBackground)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(Capsule().fill(Color.filterzAccent))
                .padding(.bottom, 126)
        }
        .transition(.opacity)
    }

    private func captureTapped() {
        switch camera.mode {
        case .photo:
            savePhoto()
        case .video:
            camera.isRecording ? stopVideoRecording() : camera.startRecording()
        }
    }

    private func savePhoto() {
        camera.isSaving = true
        Task {
            do {
                let photo = try await camera.capturePhoto()
                await MainActor.run {
                    capturedPhotoData = photo.data
                    capturedPhotoOrientation = photo.orientation
                    camera.isSaving = false
                }
            } catch {
                await MainActor.run {
                    camera.errorMessage = error.localizedDescription
                    camera.isSaving = false
                }
            }
        }
    }

    private func saveCapturedPhoto(_ data: Data) {
        camera.isSaving = true
        Task {
            do {
                try await photoLibraryClient.saveImageData(data)
                await MainActor.run {
                    capturedPhotoData = nil
                }
                await showStatus("사진이 저장되었습니다.")
            } catch {
                await MainActor.run {
                    camera.errorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                camera.isSaving = false
            }
        }
    }

    private func stopVideoRecording() {
        camera.isSaving = true
        Task {
            do {
                let url = try await camera.stopRecording()
                try await photoLibraryClient.saveVideoFile(url)
                await showStatus("동영상이 저장되었습니다.")
            } catch {
                await MainActor.run {
                    camera.errorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                camera.isSaving = false
            }
        }
    }

    @MainActor
    private func showStatus(_ message: String) async {
        statusMessage = message
        try? await Task.sleep(for: .seconds(1.4))
        if statusMessage == message {
            statusMessage = nil
        }
    }

    private func zoomLabel(_ factor: CGFloat) -> String {
        if factor == floor(factor) {
            return "\(Int(factor))x"
        }
        return String(format: "%.1fx", factor)
    }

    private var controlRotation: Angle {
        .degrees(camera.deviceOrientation.controlRotationDegrees)
    }

    private func previewImage(from data: Data, orientation: CameraDeviceOrientation) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        let isLandscapeCapture = orientation == .landscapeLeft || orientation == .landscapeRight
        guard isLandscapeCapture, image.size.height > image.size.width else {
            return image
        }

        let size = CGSize(width: image.size.height, height: image.size.width)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: size.width / 2, y: size.height / 2)
            cgContext.rotate(by: orientation == .landscapeLeft ? -.pi / 2 : .pi / 2)
            image.draw(
                in: CGRect(
                    x: -image.size.width / 2,
                    y: -image.size.height / 2,
                    width: image.size.width,
                    height: image.size.height
                )
            )
        }
    }
}
