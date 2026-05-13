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
    let photoMetadata: PhotoMetadataDTO?
    let filterValues: FilterValuesDTO?
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
    let filterValues: FilterValuesDTO?
    let isLiked: Bool
    let likeCount: Int
    let buyerCount: Int
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case filterId = "filter_id"
        case category, title, description, files, price, creator
        case filterValues = "filter_values"
        case isLiked = "is_liked"
        case likeCount = "like_count"
        case buyerCount = "buyer_count"
        case createdAt, updatedAt
    }

    init(
        id: String,
        category: String,
        title: String,
        description: String,
        files: [String],
        price: Int,
        creator: UserInfoResponseDTO,
        filterValues: FilterValuesDTO?,
        isLiked: Bool = false,
        likeCount: Int = 0,
        buyerCount: Int = 0,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.description = description
        self.files = files
        self.price = price
        self.creator = creator
        self.filterValues = filterValues
        self.isLiked = isLiked
        self.likeCount = likeCount
        self.buyerCount = buyerCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decode(String.self, forKey: .filterId)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        files = try container.decodeIfPresent([String].self, forKey: .files) ?? []
        price = try container.decodeIfPresent(Int.self, forKey: .price) ?? 0
        creator = try container.decode(UserInfoResponseDTO.self, forKey: .creator)
        filterValues = try container.decodeIfPresent(FilterValuesDTO.self, forKey: .filterValues)
        isLiked = try container.decodeIfPresent(Bool.self, forKey: .isLiked) ?? false
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        buyerCount = try container.decodeIfPresent(Int.self, forKey: .buyerCount) ?? 0
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
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
    let focalLength: Double?
    let aperture: Double?
    let iso: Int?
    let shutterSpeed: String?
    let pixelWidth: Int?
    let pixelHeight: Int?
    let fileSize: Double?
    let format: String?
    let dateTimeOriginal: String?
    let latitude: Double?
    let longitude: Double?

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
    let brightness: Double?
    let exposure: Double?
    let contrast: Double?
    let saturation: Double?
    let sharpness: Double?
    let blur: Double?
    let vignette: Double?
    let noiseReduction: Double?
    let highlights: Double?
    let shadows: Double?
    let temperature: Double?
    let blackPoint: Double?

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
