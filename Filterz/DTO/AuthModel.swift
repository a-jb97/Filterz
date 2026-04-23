// AuthModel.swift

import Foundation

// MARK: - Request DTOs

struct RefreshTokenRequestDTO: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "RefreshToken"
    }
}

// MARK: - Response DTOs

struct RefreshTokenResponseDTO: Decodable {
    let accessToken: String
}
