// AuthModel.swift

import Foundation

// MARK: - Request DTOs

struct RefreshTokenRequestDTO: Encodable, Sendable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "RefreshToken"
    }
}

// MARK: - Response DTOs

struct RefreshTokenResponseDTO: Decodable, Sendable {
    let accessToken: String
}
