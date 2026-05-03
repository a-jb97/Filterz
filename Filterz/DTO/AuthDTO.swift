// AuthDTO.swift

import Foundation

// MARK: - Request DTOs

nonisolated struct RefreshTokenRequestDTO: Encodable, Sendable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "RefreshToken"
    }
}

// MARK: - Response DTOs

nonisolated struct RefreshTokenResponseDTO: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
}
