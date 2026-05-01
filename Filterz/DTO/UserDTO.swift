// UserDTO.swift

import Foundation

// MARK: - Request DTOs

nonisolated struct EmailValidationRequestDTO: Encodable, Sendable {
    let email: String
}

nonisolated struct JoinRequestDTO: Encodable, Sendable {
    let email: String
    let password: String
    let nick: String
    let name: String?
    let introduction: String?
    let deviceToken: String?
}

nonisolated struct LoginRequestDTO: Encodable, Sendable {
    let email: String
    let password: String
    let deviceToken: String?
}

nonisolated struct KakaoLoginRequestDTO: Encodable, Sendable {
    let oauthToken: String
    let deviceToken: String?
}

nonisolated struct AppleLoginRequestDTO: Encodable, Sendable {
    let idToken: String
    let deviceToken: String?
}

// MARK: - Response DTOs

nonisolated struct LoginResponseDTO: Decodable, Sendable {
    let userID: String
    let email: String
    let nick: String
    let profileImage: String?
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case nick
        case profileImage
        case accessToken
        case refreshToken
    }
}

typealias JoinResponseDTO = LoginResponseDTO

nonisolated struct MyInfoResponseDTO: Decodable, Sendable {
    let userID: String
    let email: String
    let nick: String
    let name: String?
    let introduction: String?
    let profileImage: String?
    let followers: [UserInfoResponseDTO]
    let following: [UserInfoResponseDTO]

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case nick
        case name
        case introduction
        case profileImage
        case followers
        case following
    }
}

nonisolated struct UserInfoResponseDTO: Decodable, Sendable {
    let userID: String
    let nick: String
    let profileImage: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case nick
        case profileImage
    }
}

nonisolated struct TodayAuthorUserDTO: Decodable, Sendable {
    let userID: String
    let nick: String
    let name: String?
    let profileImage: String?
    let introduction: String?
    let description: String?
    let hashTags: [String]?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case nick, name, profileImage, introduction, description, hashTags
    }
}

nonisolated struct TodayAuthorResponseDTO: Decodable, Sendable {
    let author: TodayAuthorUserDTO
    let filters: [TodayAuthorFilterDTO]?

    enum CodingKeys: String, CodingKey {
        case author, filters
    }
}

nonisolated struct WithdrawResponseDTO: Decodable, Sendable {
    let userID: String
    let email: String
    let nick: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case nick
    }
}
