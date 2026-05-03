// PostDTO.swift

import Foundation

// MARK: - Response DTOs

nonisolated struct PostResponseDTO: Decodable, Sendable {
    let postId: String
    let category: String
    let title: String
    let content: String
    let geolocation: Geolocation?
    let creator: UserInfoResponseDTO
    let files: [String]
    let isLike: Bool
    let likeCount: Double
    let comments: [PostCommentResponseDTO]
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case category, title, content, geolocation, creator, files
        case isLike = "is_like"
        case likeCount = "like_count"
        case comments, createdAt, updatedAt
    }
}

nonisolated struct PostSummaryResponseDTO: Decodable, Sendable {
    let postId: String
    let category: String
    let title: String
    let content: String
    let geolocation: Geolocation?
    let creator: UserInfoResponseDTO
    let files: [String]
    let isLike: Bool
    let likeCount: Double
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case category, title, content, geolocation, creator, files
        case isLike = "is_like"
        case likeCount = "like_count"
        case createdAt, updatedAt
    }
}

nonisolated struct PostCommentResponseDTO: Decodable, Sendable {
    let commentId: String
    let content: String
    let createdAt: String
    let creator: UserInfoResponseDTO
    let replies: [CommentResponseDTO]

    enum CodingKeys: String, CodingKey {
        case commentId = "comment_id"
        case content, createdAt, creator, replies
    }
}

nonisolated struct PostLikeResponseDTO: Decodable, Sendable {
    let likeStatus: Bool

    enum CodingKeys: String, CodingKey {
        case likeStatus = "like_status"
    }
}

nonisolated struct PostSummaryListResponseDTO: Decodable, Sendable {
    let data: [PostSummaryResponseDTO]
}

nonisolated struct PostSummaryPaginationResponseDTO: Decodable, Sendable {
    let data: [PostSummaryResponseDTO]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
    }
}

// MARK: - Request DTOs

nonisolated struct CreatePostRequestDTO: Encodable, Sendable {
    let category: String
    let title: String
    let content: String
    let geolocation: Geolocation?
    let files: [String]?
}

nonisolated struct PostFileResponseDTO: Decodable, Sendable {
    let files: [String]
}
