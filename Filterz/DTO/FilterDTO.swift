// FilterDTO.swift

import Foundation

// MARK: - Response DTOs

nonisolated struct FilterResponseDTO: Decodable, Sendable {
    let filterId: String
    let category: String
    let title: String
    let description: String
    let files: [String]
    let price: Int
    let creator: UserInfoResponseDTO
    let photoMetadata: PhotoMetadataDTO
    let filterValues: FilterValuesDTO
    let isLiked: Bool
    let isDownloaded: Bool
    let likeCount: Int
    let buyerCount: Int
    let comments: [FilterCommentResponseDTO]
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case filterId = "filter_id"
        case category, title, description, files, price, creator
        case photoMetadata, filterValues
        case isLiked = "is_liked"
        case isDownloaded = "is_downloaded"
        case likeCount = "like_count"
        case buyerCount = "buyer_count"
        case comments, createdAt, updatedAt
    }
}

nonisolated struct FilterSummaryResponseDTO: Decodable, Sendable {
    let filterId: String
    let category: String
    let title: String
    let description: String
    let files: [String]
    let creator: UserInfoResponseDTO
    let isLiked: Bool
    let likeCount: Int
    let buyerCount: Int
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case filterId = "filter_id"
        case category, title, description, files, creator
        case isLiked = "is_liked"
        case likeCount = "like_count"
        case buyerCount = "buyer_count"
        case createdAt, updatedAt
    }
}

nonisolated struct FilterSummaryResponseDTO_Order: Decodable, Sendable {
    let id: String
    let category: String
    let title: String
    let description: String
    let files: [String]
    let price: Int
    let creator: UserInfoResponseDTO
    let filterValues: FilterValuesDTO
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, category, title, description, files, price, creator
        case filterValues = "filter_values"
        case createdAt, updatedAt
    }
}

nonisolated struct FilterListResponseDTO: Decodable, Sendable {
    let data: [FilterSummaryResponseDTO]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
    }
}

nonisolated struct FilterSummaryListResponseDTO: Decodable, Sendable {
    let data: [FilterSummaryResponseDTO]
}

nonisolated struct FilterSummaryPaginationListResponseDTO: Decodable, Sendable {
    let data: [FilterSummaryResponseDTO]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
    }
}

nonisolated struct UserFilterListRequestDTO: Encodable, Sendable {
    let next: String?
    let limit: Int?
    let category: String?
}

nonisolated struct LikedFilterListRequestDTO: Encodable, Sendable {
    let next: String?
    let limit: Int?
    let category: String?
}

nonisolated struct FilterCommentRequestDTO: Encodable, Sendable {
    let content: String
    let parentComment: String?

    enum CodingKeys: String, CodingKey {
        case content
        case parentComment = "parent_comment_id"
    }
}

nonisolated struct FilterLikeRequestDTO: Encodable, Sendable {
    let likeStatus: Bool

    enum CodingKeys: String, CodingKey {
        case likeStatus = "like_status"
    }
}

nonisolated struct FilterLikeResponseDTO: Decodable, Sendable {
    let likeStatus: Bool

    enum CodingKeys: String, CodingKey {
        case likeStatus = "like_status"
    }
}

nonisolated struct FilterCommentResponseDTO: Decodable, Sendable {
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

nonisolated struct TodayAuthorFilterDTO: Decodable, Sendable {
    let filterId: String
    let files: [String]

    enum CodingKeys: String, CodingKey {
        case filterId = "filter_id"
        case files
    }
}

nonisolated struct TodayFilterResponseDTO: Decodable, Sendable {
    let filterId: String
    let title: String
    let introduction: String
    let description: String
    let files: [String]
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case filterId = "filter_id"
        case title, introduction, description, files, createdAt, updatedAt
    }
}

// MARK: - Nested DTOs

// MARK: - Request DTOs

nonisolated struct CreateFilterRequestDTO: Encodable, Equatable, Sendable {
    let category: String
    let title: String
    let description: String
    let files: [String]
    let price: Int
    let photoMetadata: PhotoMetadataDTO?
    let filterValues: FilterValuesDTO?

    enum CodingKeys: String, CodingKey {
        case category, title, description, files, price
        case photoMetadata = "photo_metadata"
        case filterValues  = "filter_values"
    }
}

nonisolated struct PhotoMetadataDTO: Codable, Equatable, Sendable {
    let camera: String?
    let lensInfo: String?
    let focalLength: Float?
    let aperture: Float?
    let iso: Int?
    let shutterSpeed: String?
    let pixelWidth: Int?
    let pixelHeight: Int?
    let fileSize: Double?
    let format: String?
    let dateTimeOriginal: String?
    let latitude: Float?
    let longitude: Float?

    enum CodingKeys: String, CodingKey {
        case camera
        case lensInfo = "lens_info"
        case focalLength = "focal_length"
        case aperture, iso
        case shutterSpeed = "shutter_speed"
        case pixelWidth = "pixel_width"
        case pixelHeight = "pixel_height"
        case fileSize = "file_size"
        case format
        case dateTimeOriginal = "date_time_original"
        case latitude, longitude
    }
}

nonisolated struct FilterValuesDTO: Codable, Equatable, Sendable {
    let brightness: Float?
    let exposure: Float?
    let contrast: Float?
    let saturation: Float?
    let sharpness: Float?
    let blur: Float?
    let vignette: Float?
    let noiseReduction: Float?
    let highlights: Float?
    let shadows: Float?
    let temperature: Float?
    let blackPoint: Float?

    enum CodingKeys: String, CodingKey {
        case brightness, exposure, contrast, saturation, sharpness
        case blur, vignette
        case noiseReduction = "noise_reduction"
        case highlights, shadows, temperature
        case blackPoint = "black_point"
    }
}

nonisolated struct CommentResponseDTO: Decodable, Sendable {
    let commentId: String
    let content: String
    let createdAt: String
    let creator: UserInfoResponseDTO

    enum CodingKeys: String, CodingKey {
        case commentId = "comment_id"
        case content, createdAt, creator
    }
}
