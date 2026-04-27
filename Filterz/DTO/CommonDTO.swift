// CommonDTO.swift

import Foundation

// MARK: - Geolocation

struct Geolocation: Codable, Sendable {
    let longitude: Double
    let latitude: Double
}

// MARK: - Banner

struct BannerDTO: Decodable, Sendable, Equatable {
    let name: String
    let imageUrl: String
    let payload: BannerPayload?
}

struct BannerListResponseDTO: Decodable, Sendable {
    let data: [BannerDTO]
}

struct BannerPayload: Decodable, Equatable {
    let type: String
    let value: String
}

// MARK: - Log

struct LogDTO: Decodable, Sendable {
    let date: String
    let name: String
    let method: String
    let routePath: String
    let body: String?
    let contentType: String?
    let statusCode: Int

    enum CodingKeys: String, CodingKey {
        case date, name, method
        case routePath = "route_path"
        case body, contentType
        case statusCode = "status_code"
    }
}

struct LogListResponseDTO: Decodable, Sendable {
    let count: Int
    let logs: [LogDTO]
}

// MARK: - File

struct FileResponseDTO: Decodable, Sendable {
    let files: [String]
}

// MARK: - Notification Request

struct PushNotificationRequestDTO: Encodable, Sendable {
    let userId: String
    let title: String
    let subtitle: String?
    let body: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case title, subtitle, body
    }
}
