import AVKit
import SwiftUI
import ComposableArchitecture

struct VideoPlayerView: View {
    @Bindable var store: StoreOf<VideoPlayerFeature>
    @State private var player: AVPlayer?
    @State private var statusObserver: NSKeyValueObservation?
    @State private var isFullScreenPresented = false

    var body: some View {
        ZStack {
            Color.filterzBlackBase.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                if player == nil {
                    Spacer()
                    ProgressView().tint(.filterzGray45)
                    Spacer()
                } else if let player {
                    ZStack(alignment: .topTrailing) {
                        VideoPlayer(player: player)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black)
                            .onAppear { player.play() }

                        Button {
                            isFullScreenPresented = true
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.filterzGray30)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.black.opacity(0.48)))
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 16)
                        .padding(.trailing, 16)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .filterzSwipeBack {
            store.send(.backTapped)
        }
        .task(id: store.stream.streamURL) {
            preparePlayer(urlString: store.stream.streamURL)
        }
        .onAppear {
            OrientationBridge.setSupportedOrientations(.allButUpsideDown)
        }
        .onDisappear {
            statusObserver?.invalidate()
            statusObserver = nil
            player?.pause()
            OrientationBridge.setSupportedOrientations(.portrait)
            OrientationBridge.requestPortrait()
        }
        .alert(
            "오류",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.send(.errorDismissed) } }
            )
        ) {
            Button("확인") { store.send(.errorDismissed) }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .fullScreenCover(isPresented: $isFullScreenPresented) {
            if let player {
                FullScreenVideoPlayer(player: player) {
                    isFullScreenPresented = false
                }
                .ignoresSafeArea()
            }
        }
    }

    private var navBar: some View {
        HStack {
            Button {
                store.send(.backTapped)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.filterzGray30)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(store.video.title)
                .font(.pretendard(17, weight: .bold))
                .foregroundColor(.filterzGray30)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: 56)
        .background(Color.filterzBlackBase)
    }

    private func preparePlayer(urlString: String) {
        guard let url = store.stream.playbackURL else {
            store.send(.playbackFailed("재생 URL 형식이 올바르지 않습니다."))
            return
        }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        statusObserver = item.observe(\.status, options: [.new]) { item, _ in
            if item.status == .failed {
                Task { @MainActor in
                    store.send(.playbackFailed(playbackFailureMessage(for: item, url: url)))
                }
            }
        }
        self.player = player
        player.play()
    }

    private func playbackFailureMessage(for item: AVPlayerItem, url: URL) -> String {
        if let event = item.errorLog()?.events.last {
            let status = event.errorStatusCode == 0 ? "" : "HTTP \(event.errorStatusCode)"
            let comment = event.errorComment ?? event.errorDomain
            return [status, comment].filter { !$0.isEmpty }.joined(separator: " - ")
        }

        if let error = item.error {
            return error.localizedDescription
        }

        return url.absoluteString
    }
}

private struct FullScreenVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let viewController = AVPlayerViewController()
        viewController.player = player
        viewController.showsPlaybackControls = true
        viewController.delegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ viewController: AVPlayerViewController, context: Context) {
        viewController.player = player
        player.play()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func playerViewControllerWillEndFullScreenPresentation(_ playerViewController: AVPlayerViewController) {
            onDismiss()
        }
    }
}
