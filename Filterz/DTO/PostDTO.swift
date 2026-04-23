// PostDTO.swift

import Foundation

// MARK: - Response DTOs

struct PostResponseDTO: Decodable {
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

struct PostSummaryResponseDTO: Decodable {
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

struct PostCommentResponseDTO: Decodable {
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

struct PostLikeResponseDTO: Decodable {
    let likeStatus: Bool

    enum CodingKeys: String, CodingKey {
        case likeStatus = "like_status"
    }
}

struct PostSummaryListResponseDTO: Decodable {
    let data: [PostSummaryResponseDTO]
}

struct PostSummaryPaginationResponseDTO: Decodable {
    let data: [PostSummaryResponseDTO]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
    }
}

// MARK: - Request DTOs

struct CreatePostRequestDTO: Encodable {
    let category: String
    let title: String
    let content: String
    let geolocation: Geolocation?
    let files: [String]?
}

struct PostFileResponseDTO: Decodable {
    let files: [String]
}
