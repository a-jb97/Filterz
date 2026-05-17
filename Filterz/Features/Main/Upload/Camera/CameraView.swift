import ComposableArchitecture
import SwiftUI

struct CameraView: View {
    @Bindable var store: StoreOf<CameraFeature>
    let onDismiss: () -> Void
    let onPhotoSelected: (Data) -> Void

    var body: some View {
        ZStack {
            Color.filterzBackground.ignoresSafeArea()

            switch store.permissionStatus {
            case .authorized:
                cameraContent
            case .notDetermined:
                ProgressView()
                    .tint(Color.filterzAccent)
            case .denied:
                permissionDeniedView
            }
        }
        .task { store.send(.onAppear) }
        .onDisappear { store.send(.onDisappear) }
        .alert("카메라 오류", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.send(.errorDismissed) } }
        )) {
            Button("확인") { store.send(.errorDismissed) }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var cameraContent: some View {
        if let data = store.capturedPhotoData, let image = UIImage(data: data) {
            capturedPreview(image)
        } else {
            liveCameraView
        }
    }

    private var liveCameraView: some View {
        ZStack {
            if let session = store.session?.session {
                CameraPreviewView(session: session)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(Color.filterzAccent)
            }

            VStack(spacing: 0) {
                liveTopBar
                Spacer()
                zoomControls
                    .padding(.bottom, 20)
                liveBottomBar
            }
        }
    }

    private var liveTopBar: some View {
        HStack {
            Button {
                store.send(.closeTapped)
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.filterzGray30)
                    .rotationEffect(controlRotation)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.42)))
            }

            Spacer()

            Button {
                store.send(.flashTapped)
            } label: {
                Image(systemName: store.flashMode.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(store.supportsFlash ? Color.filterzAccent : Color.filterzGray30)
                    .rotationEffect(controlRotation)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.42)))
            }
            .disabled(!store.supportsFlash)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    private var zoomControls: some View {
        HStack(spacing: 8) {
            ForEach(store.supportedZoomOptions) { option in
                Button {
                    store.send(.zoomTapped(option))
                } label: {
                    Text(zoomLabel(option.displayFactor))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.filterzAccent)
                        .rotationEffect(controlRotation)
                        .frame(width: 42, height: 32)
                        .background(
                            Capsule().fill(Color.filterzBackground)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.black.opacity(0.28)))
    }

    private var liveBottomBar: some View {
        HStack {
            Color.clear
                .frame(width: 64, height: 64)

            Spacer()

            Button {
                store.send(.captureTapped)
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.filterzGray30, lineWidth: 4)
                        .frame(width: 78, height: 78)
                    Circle()
                        .fill(store.isCapturing ? Color.filterzGray30 : Color.filterzGray30)
                        .frame(width: 62, height: 62)
                    if store.isCapturing {
                        ProgressView()
                            .tint(Color.filterzBackground)
                    }
                }
            }
            .disabled(store.isCapturing || store.session == nil)
            .buttonStyle(.plain)

            Spacer()

            Button {
                store.send(.switchCameraTapped)
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.filterzGray30)
                    .rotationEffect(controlRotation)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Color.black.opacity(0.42)))
            }
            .disabled(store.isCapturing)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 34)
        .padding(.bottom, 34)
    }

    private func capturedPreview(_ image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        store.send(.retakeTapped)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.filterzGray30)
                            .rotationEffect(controlRotation)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.black.opacity(0.42)))
                    }

                    Spacer()

                    Button {
                        store.send(.usePhotoTapped)
                        if let data = store.capturedPhotoData {
                            onPhotoSelected(data)
                        }
                    } label: {
                        Group {
                            if store.isWritingMetadata {
                                ProgressView()
                                    .tint(Color.filterzBackground)
                            } else {
                                Text("등록")
                                    .font(.filterzCaption())
                                    .foregroundStyle(Color.filterzAccent)
                            }
                        }
                        .rotationEffect(controlRotation)
                        .padding(.horizontal, 16)
                        .frame(minWidth: 58, minHeight: 38)
                        .background(Capsule().fill(Color.filterzBackground))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isWritingMetadata)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)

                Spacer()
            }
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.filterzAccent)

            Text("카메라 권한이 필요합니다.")
                .font(.filterzBody())
                .foregroundStyle(Color.filterzGray30)

            Text("설정에서 카메라 접근을 허용한 뒤 다시 시도해주세요.")
                .font(.filterzCaption())
                .foregroundStyle(Color.filterzGray30)
                .multilineTextAlignment(.center)

            Button {
                store.send(.closeTapped)
                onDismiss()
            } label: {
                Text("닫기")
                    .font(.filterzCaption())
                    .foregroundStyle(Color.filterzAccent)
                    .rotationEffect(controlRotation)
                    .padding(.horizontal, 22)
                    .frame(height: 42)
                    .background(Capsule().fill(Color.filterzBackground))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.horizontal, 32)
    }

    private func zoomLabel(_ factor: CGFloat) -> String {
        if factor == floor(factor) {
            return "\(Int(factor))x"
        }
        return String(format: "%.1fx", factor)
    }

    private var controlRotation: Angle {
        .degrees(store.deviceOrientation.controlRotationDegrees)
    }
}
