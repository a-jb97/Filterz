// VideoDTO.swift

import Foundation

// MARK: - Response DTOs

nonisolated struct VideoResponseDTO: Decodable, Sendable {
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

nonisolated struct StreamUrlResponseDTO: Decodable, Sendable {
    let videoId: String
    let streamUrl: String
    let qualities: [[String: String]]
    let subtitles: [[String: String]]

    enum CodingKeys: String, CodingKey {
        case videoId = "video_id"
        case streamUrl = "stream_url"
        case qualities, subtitles
    }
}

nonisolated struct VideoListResponseDTO: Decodable, Sendable {
    let data: [VideoResponseDTO]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
    }
}

// MARK: - Request DTOs

nonisolated struct VideoLikeRequestDTO: Encodable, Sendable {
    let likeStatus: Bool

    enum CodingKeys: String, CodingKey {
        case likeStatus = "like_status"
    }
}
