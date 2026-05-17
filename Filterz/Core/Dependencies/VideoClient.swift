import ComposableArchitecture
import Foundation

struct VideoClient: Sendable {
    var getVideos: @Sendable (_ query: VideoListRequestDTO) async throws -> VideoListResponseDTO
    var getStreamURL: @Sendable (_ id: String) async throws -> StreamUrlResponseDTO
    var likeVideo: @Sendable (_ id: String, _ status: Bool) async throws -> Void
}

extension VideoClient: DependencyKey {
    static var liveValue: VideoClient {
        VideoClient(
            getVideos: { query in
                try await NetworkManager.shared.request(.getVideos(query: query))
            },
            getStreamURL: { id in
                try await NetworkManager.shared.request(.getStreamURL(id: id))
            },
            likeVideo: { id, status in
                try await NetworkManager.shared.requestVoid(.likeVideo(id: id, query: VideoLikeRequestDTO(likeStatus: status)))
            }
        )
    }

    static var testValue: VideoClient {
        VideoClient(
            getVideos: { _ in VideoListResponseDTO(data: [], nextCursor: nil) },
            getStreamURL: { id in
                StreamUrlResponseDTO(
                    videoId: id,
                    streamUrl: "https://example.com/video.m3u8?token=test",
                    qualities: [],
                    subtitles: []
                )
            },
            likeVideo: { _, _ in }
        )
    }
}

extension DependencyValues {
    var videoClient: VideoClient {
        get { self[VideoClient.self] }
        set { self[VideoClient.self] = newValue }
    }
}
