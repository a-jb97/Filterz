// VideoDTO.swift

import Foundation

// MARK: - Response DTOs

nonisolated struct VideoResponseDTO: Decodable, Sendable, Equatable {
    let videoId: String
    let fileName: String
    let title: String
    let description: String
    let duration: Double
    let thumbnailUrl: String
    let availableQualities: [String]
    let viewCount: Int
    let likeCount: Int
    let isLiked: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case videoId = "video_id"
        case fileName = "file_name"
        case title, description, duration
        case thumbnailUrl = "thumbnail_url"
        case availableQualities = "available_qualities"
        case viewCount = "view_count"
        case likeCount = "like_count"
        case isLiked = "is_liked"
        case createdAt
    }
}

nonisolated struct VideoQualityDTO: Decodable, Sendable, Equatable {
    let quality: String
    let streamUrl: String

    enum CodingKeys: String, CodingKey {
        case quality
        case name
        case url
        case streamUrl = "stream_url"
    }

    init(quality: String, streamUrl: String) {
        self.quality = quality
        self.streamUrl = streamUrl
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        quality = try container.decodeIfPresent(String.self, forKey: .quality)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? ""
        streamUrl = try container.decodeIfPresent(String.self, forKey: .streamUrl)
            ?? container.decode(String.self, forKey: .url)
    }
}

nonisolated struct VideoSubtitleDTO: Decodable, Sendable, Equatable {
    let language: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case language
        case lang
        case url
    }

    init(language: String, url: String) {
        self.language = language
        self.url = url
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        language = try container.decodeIfPresent(String.self, forKey: .language)
            ?? container.decodeIfPresent(String.self, forKey: .lang)
            ?? ""
        url = try container.decode(String.self, forKey: .url)
    }
}

nonisolated struct StreamUrlResponseDTO: Decodable, Sendable, Equatable {
    let videoId: String
    let streamUrl: String
    let qualities: [VideoQualityDTO]
    let subtitles: [VideoSubtitleDTO]

    enum CodingKeys: String, CodingKey {
        case videoId = "video_id"
        case streamUrl = "stream_url"
        case qualities, subtitles
    }
}

nonisolated struct VideoListResponseDTO: Decodable, Sendable, Equatable {
    let data: [VideoResponseDTO]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
    }
}

// MARK: - Request DTOs

nonisolated struct VideoListRequestDTO: Encodable, Sendable, Equatable {
    let next: String?
    let limit: Int?
}

nonisolated struct VideoLikeRequestDTO: Encodable, Sendable {
    let likeStatus: Bool

    enum CodingKeys: String, CodingKey {
        case likeStatus = "like_status"
    }
}
