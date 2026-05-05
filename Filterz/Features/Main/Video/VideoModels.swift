import Foundation

struct VideoItem: Identifiable, Equatable, Sendable {
    let id: String
    let fileName: String
    let title: String
    let description: String
    let duration: Double
    let thumbnailURL: String?
    let availableQualities: [String]
    let viewCount: Int
    let likeCount: Int
    let isLiked: Bool
    let createdAt: String

    nonisolated init(dto: VideoResponseDTO) {
        id = dto.videoId
        fileName = dto.fileName
        title = dto.title
        description = dto.description
        duration = dto.duration
        thumbnailURL = dto.thumbnailUrl
        availableQualities = dto.availableQualities
        viewCount = dto.viewCount
        likeCount = dto.likeCount
        isLiked = dto.isLiked
        createdAt = dto.createdAt
    }

    nonisolated init(
        id: String,
        fileName: String,
        title: String,
        description: String,
        duration: Double,
        thumbnailURL: String?,
        availableQualities: [String],
        viewCount: Int,
        likeCount: Int,
        isLiked: Bool,
        createdAt: String
    ) {
        self.id = id
        self.fileName = fileName
        self.title = title
        self.description = description
        self.duration = duration
        self.thumbnailURL = thumbnailURL
        self.availableQualities = availableQualities
        self.viewCount = viewCount
        self.likeCount = likeCount
        self.isLiked = isLiked
        self.createdAt = createdAt
    }

    nonisolated func updatingLike(isLiked: Bool) -> VideoItem {
        let delta: Int
        if self.isLiked == isLiked {
            delta = 0
        } else {
            delta = isLiked ? 1 : -1
        }
        return VideoItem(
            id: id,
            fileName: fileName,
            title: title,
            description: description,
            duration: duration,
            thumbnailURL: thumbnailURL,
            availableQualities: availableQualities,
            viewCount: viewCount,
            likeCount: max(0, likeCount + delta),
            isLiked: isLiked,
            createdAt: createdAt
        )
    }

    nonisolated var durationText: String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct VideoStream: Equatable, Sendable {
    let videoId: String
    let streamURL: String
    let qualities: [VideoQualityDTO]
    let subtitles: [VideoSubtitleDTO]

    nonisolated init(dto: StreamUrlResponseDTO) {
        videoId = dto.videoId
        streamURL = dto.streamUrl
        qualities = dto.qualities
        subtitles = dto.subtitles
    }

    nonisolated var playbackURL: URL? {
        if let absoluteURL = URL(string: streamURL), absoluteURL.scheme != nil {
            return absoluteURL
        }

        guard let baseURL = URL(string: APIKey.baseURL) else {
            return nil
        }

        let normalizedBase = APIKey.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let origin = baseURL.scheme.flatMap { scheme in
            baseURL.host.map { host in
                let port = baseURL.port.map { ":\($0)" } ?? ""
                return "\(scheme)://\(host)\(port)"
            }
        }

        if streamURL.hasPrefix("/") {
            let basePath = baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !basePath.isEmpty, !streamURL.hasPrefix("/\(basePath)/") {
                return URL(string: normalizedBase + streamURL)
            }
            if let origin {
                return URL(string: origin + streamURL)
            }
        }

        return URL(string: normalizedBase + "/" + streamURL)
    }
}
