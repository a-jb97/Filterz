import AVKit
import MediaPlayer
import SwiftUI
import ComposableArchitecture

struct VideoPlayerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var store: StoreOf<VideoPlayerFeature>
    @State private var player: AVPlayer?
    @State private var statusObserver: NSKeyValueObservation?
    @State private var playbackURLs: [URL] = []
    @State private var isSceneInactiveOrBackground = false
    @State private var nowPlayingArtworkTask: Task<Void, Never>?
    @State private var remoteCommandTargets: [Any] = []
    @State private var subtitleText: String? = nil
    @State private var subtitleObserver: (player: AVPlayer, token: Any)?

    var body: some View {
        ZStack {
            Color.filterzBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                if player == nil {
                    Spacer()
                    ProgressView().tint(.filterzGray30)
                    Spacer()
                } else if let player {
                    ZStack(alignment: .bottom) {
                        FilterzVideoPlayer(player: player)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black)
                            .onAppear { player.play() }

                        if let text = subtitleText {
                            Text(text)
                                .font(.pretendard(16, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.65))
                                .cornerRadius(4)
                                .padding(.bottom, 64)
                        }
                    }
                    .onChange(of: store.subtitleCues) { _, cues in
                        setupSubtitleObserver(for: player, cues: cues)
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
            store.send(.onAppear)
            isSceneInactiveOrBackground = false
            OrientationBridge.setSupportedOrientations(.allButUpsideDown)
        }
        .onChange(of: scenePhase) { _, phase in
            isSceneInactiveOrBackground = phase != .active
            if phase != .active, let player {
                configureNowPlayingInfo(for: player)
            }
            if phase == .active {
                OrientationBridge.setSupportedOrientations(.allButUpsideDown)
            }
        }
        .onDisappear {
            guard !isSceneInactiveOrBackground else {
                return
            }
            statusObserver?.invalidate()
            statusObserver = nil
            nowPlayingArtworkTask?.cancel()
            nowPlayingArtworkTask = nil
            removeRemoteCommandTargets()
            tearDownSubtitleObserver()
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            MPNowPlayingInfoCenter.default().playbackState = .stopped
            UIApplication.shared.endReceivingRemoteControlEvents()
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

            if let tracks = store.segmentInfo?.subtitleTracks, !tracks.isEmpty {
                Menu {
                    Button {
                        store.send(.subtitleSelected(nil))
                    } label: {
                        Label("끄기", systemImage: "xmark")
                    }
                    ForEach(tracks, id: \.language) { track in
                        Button {
                            store.send(.subtitleSelected(track))
                        } label: {
                            Text(track.language)
                        }
                    }
                } label: {
                    Image(systemName: store.selectedSubtitle != nil ? "captions.bubble.fill" : "captions.bubble")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.filterzGray30)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 56)
        .background(Color.filterzBackground)
    }

    private func preparePlayer(urlString: String) {
        let urls = store.stream.playbackURLs
        guard !urls.isEmpty else {
            store.send(.playbackFailed("재생 URL 형식이 올바르지 않습니다."))
            return
        }
        configurePlaybackAudioSession()
        playbackURLs = urls
        playURL(at: 0)
    }

    private func playURL(at index: Int) {
        guard playbackURLs.indices.contains(index) else {
            store.send(.playbackFailed("재생 가능한 스트림 URL을 찾을 수 없습니다."))
            return
        }

        statusObserver?.invalidate()
        statusObserver = nil

        let url = playbackURLs[index]
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": [
                "SeSACKey": APIKey.apiKey,
                "Authorization": APIKey.accessToken
            ]
        ])
        let item = AVPlayerItem(asset: asset)
        item.externalMetadata = externalMetadata()
        let player = AVPlayer(playerItem: item)
        statusObserver = item.observe(\.status, options: [.new]) { item, _ in
            if item.status == .failed {
                Task { @MainActor in
                    if playbackURLs.indices.contains(index + 1) {
                        playURL(at: index + 1)
                    } else {
                        store.send(.playbackFailed(playbackFailureMessage(for: item, url: url)))
                    }
                }
            }
        }
        self.player = player
        configureRemoteCommands(for: player)
        configureNowPlayingInfo(for: player)
        player.play()
        updateNowPlayingPlaybackState(for: player)
        if !store.subtitleCues.isEmpty {
            setupSubtitleObserver(for: player, cues: store.subtitleCues)
        }
    }

    private func setupSubtitleObserver(for player: AVPlayer, cues: [VTTCue]) {
        if let prev = subtitleObserver {
            prev.player.removeTimeObserver(prev.token)
            subtitleObserver = nil
        }
        subtitleText = nil
        guard !cues.isEmpty else { return }

        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let token = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let seconds = time.seconds
            subtitleText = cues.first { $0.start <= seconds && seconds < $0.end }?.text
        }
        subtitleObserver = (player: player, token: token)
    }

    private func tearDownSubtitleObserver() {
        if let prev = subtitleObserver {
            prev.player.removeTimeObserver(prev.token)
            subtitleObserver = nil
        }
        subtitleText = nil
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

    private func configurePlaybackAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
#if DEBUG
            print("Failed to configure playback audio session: \(error.localizedDescription)")
#endif
        }
    }

    private func configureNowPlayingInfo(for player: AVPlayer) {
        let elapsedTime = player.currentTime().seconds
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: store.video.title,
            MPMediaItemPropertyArtist: "Filterz",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]

        if store.video.duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = store.video.duration
        }
        if elapsedTime.isFinite {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedTime
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        updateNowPlayingPlaybackState(for: player)
        UIApplication.shared.beginReceivingRemoteControlEvents()

        nowPlayingArtworkTask?.cancel()
        guard let thumbnailURL = store.video.thumbnailURL else {
            nowPlayingArtworkTask = nil
            return
        }

        nowPlayingArtworkTask = Task {
            guard let image = await loadNowPlayingArtwork(from: thumbnailURL),
                  !Task.isCancelled else {
                return
            }

            await MainActor.run {
                var updatedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? info
                updatedInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in
                    image
                }
                MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                player.currentItem?.externalMetadata = externalMetadata(artwork: image)
            }
        }
    }

    private func loadNowPlayingArtwork(from path: String) async -> UIImage? {
        let urlString = path.hasPrefix("http") ? path : APIKey.baseURL + path
        guard let url = URL(string: urlString) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue(APIKey.apiKey, forHTTPHeaderField: "SeSACKey")
        request.setValue(APIKey.accessToken, forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: request) else {
            return nil
        }
        return UIImage(data: data)
    }

    private func configureRemoteCommands(for player: AVPlayer) {
        removeRemoteCommandTargets()

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.stopCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false

        let playTarget = commandCenter.playCommand.addTarget { _ in
            Task { @MainActor in
                configurePlaybackAudioSession()
                player.play()
                updateNowPlayingPlaybackState(for: player)
            }
            return .success
        }

        let pauseTarget = commandCenter.pauseCommand.addTarget { _ in
            Task { @MainActor in
                player.pause()
                updateNowPlayingPlaybackState(for: player)
            }
            return .success
        }

        let toggleTarget = commandCenter.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in
                if player.rate == 0 {
                    configurePlaybackAudioSession()
                    player.play()
                } else {
                    player.pause()
                }
                updateNowPlayingPlaybackState(for: player)
            }
            return .success
        }

        remoteCommandTargets = [playTarget, pauseTarget, toggleTarget]
    }

    private func removeRemoteCommandTargets() {
        let commandCenter = MPRemoteCommandCenter.shared()
        for target in remoteCommandTargets {
            commandCenter.playCommand.removeTarget(target)
            commandCenter.pauseCommand.removeTarget(target)
            commandCenter.togglePlayPauseCommand.removeTarget(target)
        }
        remoteCommandTargets = []
    }

    private func updateNowPlayingPlaybackState(for player: AVPlayer) {
        let isPlaying = player.rate > 0
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused

        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        let elapsedTime = player.currentTime().seconds
        if elapsedTime.isFinite {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedTime
        }
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func externalMetadata(artwork: UIImage? = nil) -> [AVMetadataItem] {
        var metadata: [AVMetadataItem] = [
            metadataItem(identifier: .commonIdentifierTitle, value: store.video.title as NSString),
            metadataItem(identifier: .commonIdentifierArtist, value: "Filterz" as NSString)
        ]

        if let artwork, let data = artwork.pngData() {
            metadata.append(metadataItem(identifier: .commonIdentifierArtwork, value: data as NSData))
        }

        return metadata
    }

    private func metadataItem(identifier: AVMetadataIdentifier, value: any NSCopying & NSObjectProtocol) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value
        item.extendedLanguageTag = "und"
        return item.copy() as! AVMetadataItem
    }
}

private struct FilterzVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let viewController = AVPlayerViewController()
        viewController.configureFilterzPlayback(with: player)
        return viewController
    }

    func updateUIViewController(_ viewController: AVPlayerViewController, context: Context) {
        viewController.configureFilterzPlayback(with: player)
    }
}

private extension AVPlayerViewController {
    func configureFilterzPlayback(with player: AVPlayer) {
        self.player = player
        showsPlaybackControls = true
        updatesNowPlayingInfoCenter = false
        allowsPictureInPicturePlayback = AVPictureInPictureController.isPictureInPictureSupported()
        canStartPictureInPictureAutomaticallyFromInline = true
    }
}
