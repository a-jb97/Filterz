// CommonDTO.swift

import Foundation

// MARK: - Geolocation

struct Geolocation: Codable {
    let longitude: Double
    let latitude: Double
}

// MARK: - Banner

struct BannerDTO: Decodable {
    let name: String
    let imageUrl: String
    let payload: String?

    enum CodingKeys: String, CodingKey {
        case name, imageUrl, payload
    }
}

struct BannerListResponseDTO: Decodable {
    let data: [BannerDTO]
}

// MARK: - Log

struct LogDTO: Decodable {
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

struct LogListResponseDTO: Decodable {
    let count: Int
    let logs: [LogDTO]
}

// MARK: - File

struct FileResponseDTO: Decodable {
    let files: [String]
}

// MARK: - Notification Request

struct PushNotificationRequestDTO: Encodable {
    let userId: String
    let title: String
    let subtitle: String?
    let body: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case title, subtitle, body
    }
}
