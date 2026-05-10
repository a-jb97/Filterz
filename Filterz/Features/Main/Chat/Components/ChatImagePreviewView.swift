import SwiftUI
import Photos

struct ChatImagePreviewView: View {
    let paths: [String]
    let initialIndex: Int
    var onDismiss: () -> Void

    @State private var selectedIndex: Int
    @State private var dragOffset: CGFloat = 0
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var showSaveError = false

    init(paths: [String], initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.paths = paths
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        _selectedIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            ZStack {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(paths.enumerated()), id: \.offset) { index, path in
                        ZoomableChatImage(path: path)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()

                VStack {
                    topBar
                    Spacer()
                    if paths.count > 1 {
                        Text("\(selectedIndex + 1) / \(paths.count)")
                            .font(.pretendard(13, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.black.opacity(0.45)))
                            .padding(.bottom, 18)
                    }
                }

                if showSaveSuccess {
                    saveSuccessOverlay
                }
            }
            .offset(y: dragOffset)
        }
        .simultaneousGesture(dismissDragGesture)
        .alert("저장 실패", isPresented: $showSaveError) {
            Button("확인") {}
        } message: {
            Text("사진을 저장할 수 없습니다.\n사진 접근 권한을 확인해주세요.")
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                Task { await saveCurrentImage() }
            } label: {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 44, height: 44)
                } else {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.65), Color.black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 96),
            alignment: .top
        )
    }

    private var saveSuccessOverlay: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 46))
                .foregroundColor(.white)
            Text("저장되었습니다")
                .font(.pretendard(14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .background(Color.black.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .transition(.opacity.combined(with: .scale(scale: 0.88)))
    }

    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
                guard isDownwardDismissDrag(value) else { return }
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                guard isDownwardDismissDrag(value) else {
                    resetDragOffset()
                    return
                }

                if shouldDismiss(for: value) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        dragOffset = 520
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        onDismiss()
                    }
                } else {
                    resetDragOffset()
                }
            }
    }

    private var backgroundOpacity: Double {
        max(0.35, 1 - Double(dragOffset / 420))
    }

    private func isDownwardDismissDrag(_ value: DragGesture.Value) -> Bool {
        let verticalDistance = value.translation.height
        let horizontalDistance = abs(value.translation.width)
        return verticalDistance > 0 && verticalDistance > horizontalDistance * 1.25
    }

    private func shouldDismiss(for value: DragGesture.Value) -> Bool {
        value.translation.height > 120 || value.predictedEndTranslation.height > 220
    }

    private func resetDragOffset() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            dragOffset = 0
        }
    }

    private func saveCurrentImage() async {
        guard !isSaving, paths.indices.contains(selectedIndex) else { return }
        isSaving = true
        defer { isSaving = false }

        let path = paths[selectedIndex]
        guard let image = await fetchImage(for: path) else {
            showSaveError = true
            return
        }

        guard await requestPhotoLibraryAccess() else {
            showSaveError = true
            return
        }

        let success = await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { didSucceed, _ in
                continuation.resume(returning: didSucceed)
            }
        }

        if success {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showSaveSuccess = true
            }
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation {
                showSaveSuccess = false
            }
        } else {
            showSaveError = true
        }
    }

    private func requestPhotoLibraryAccess() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let result = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return result == .authorized || result == .limited
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func fetchImage(for path: String) async -> UIImage? {
        let urlString = path.hasPrefix("http") ? path : APIKey.baseURL + path
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.setValue(APIKey.apiKey, forHTTPHeaderField: "SeSACKey")
        request.setValue(APIKey.accessToken, forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let image = UIImage(data: data) else { return nil }
        return image
    }
}

private struct ZoomableChatImage: View {
    let path: String

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        AuthenticatedImageView(path: path, contentMode: .fit)
            .scaleEffect(scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(max(lastScale * value, 1), 4)
                    }
                    .onEnded { _ in
                        lastScale = scale
                        if scale < 1.05 {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                scale = 1
                                lastScale = 1
                            }
                        }
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    if scale > 1 {
                        scale = 1
                        lastScale = 1
                    } else {
                        scale = 2
                        lastScale = 2
                    }
                }
            }
    }
}
