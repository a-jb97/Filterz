import ComposableArchitecture
import Foundation

@Reducer
struct VideoPlayerFeature {
    @ObservableState
    struct State: Equatable {
        let video: VideoItem
        let stream: VideoStream
        var errorMessage: String? = nil
        var segmentInfo: HLSSegmentInfo? = nil
        var segmentInfoError: String? = nil

        var selectedSubtitle: HLSSubtitleTrack? = nil
        var subtitleCues: [VTTCue] = []
    }

    enum Action: Sendable {
        case onAppear
        case backTapped
        case playbackFailed(String?)
        case segmentInfoResponse(Result<HLSSegmentInfo, any Error>)
        case errorDismissed
        case subtitleSelected(HLSSubtitleTrack?)
        case subtitleCuesLoaded([VTTCue])
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case backTapped
        }
    }

    @Dependency(\.hlsPlaylistClient) var hlsPlaylistClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard let url = state.stream.playbackURLs.first else {
                    state.segmentInfoError = "재생 URL 형식이 올바르지 않습니다."
                    return .none
                }
                return .run { send in
                    await send(.segmentInfoResponse(
                        Result { try await hlsPlaylistClient.fetchSegmentInfo(url) }
                    ))
                }

            case .backTapped:
                return .send(.delegate(.backTapped))

            case .playbackFailed(let reason):
                if let reason, !reason.isEmpty {
                    state.errorMessage = "영상을 재생할 수 없습니다.\n\(reason)"
                } else {
                    state.errorMessage = "영상을 재생할 수 없습니다."
                }
                return .none

            case .segmentInfoResponse(.success(let info)):
                state.segmentInfo = info
                state.segmentInfoError = nil
#if DEBUG
                print("HLS segments: target=\(info.targetDurationText), count=\(info.segmentCount), avg=\(info.averageDurationText), min=\(info.minDurationText), max=\(info.maxDurationText)")
#endif
                return .none

            case .segmentInfoResponse(.failure(let error)):
                state.segmentInfo = nil
                state.segmentInfoError = error.localizedDescription
#if DEBUG
                print("Failed to load HLS segment info: \(error.localizedDescription)")
#endif
                return .none

            case .errorDismissed:
                state.errorMessage = nil
                return .none

            case .subtitleSelected(let track):
                state.selectedSubtitle = track
                state.subtitleCues = []
                guard let track else { return .none }
                return .run { send in
                    var request = URLRequest(url: track.uri)
                    request.setValue(APIKey.apiKey, forHTTPHeaderField: "SeSACKey")
                    request.setValue(APIKey.accessToken, forHTTPHeaderField: "Authorization")
                    guard
                        let (data, _) = try? await URLSession.shared.data(for: request),
                        let content = String(data: data, encoding: .utf8)
                    else { return }
#if DEBUG
                    print("VTT fetched: \(content.prefix(200))")
#endif
                    await send(.subtitleCuesLoaded(VTTParser.parse(content)))
                }

            case .subtitleCuesLoaded(let cues):
                state.subtitleCues = cues
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

private extension HLSSegmentInfo {
    var targetDurationText: String {
        targetDuration.map { String(format: "%.2fs", $0) } ?? "nil"
    }

    var averageDurationText: String {
        averageDuration.map { String(format: "%.2fs", $0) } ?? "nil"
    }

    var minDurationText: String {
        minDuration.map { String(format: "%.2fs", $0) } ?? "nil"
    }

    var maxDurationText: String {
        maxDuration.map { String(format: "%.2fs", $0) } ?? "nil"
    }
}
