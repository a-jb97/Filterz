// UserDTO.swift

import Foundation

// MARK: - Request DTOs

struct EmailValidationRequestDTO: Encodable, Sendable {
    let email: String
}

struct JoinRequestDTO: Encodable, Sendable {
    let email: String
    let password: String
    let nick: String
    let name: String?
    let introduction: String?
    let deviceToken: String?
}

struct LoginRequestDTO: Encodable, Sendable {
    let email: String
    let password: String
    let deviceToken: String?
}

struct KakaoLoginRequestDTO: Encodable, Sendable {
    let oauthToken: String
    let deviceToken: String?
}

struct AppleLoginRequestDTO: Encodable, Sendable {
    let idToken: String
    let deviceToken: String?
}

// MARK: - Response DTOs

struct LoginResponseDTO: Decodable, Sendable {
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

struct MyInfoResponseDTO: Decodable, Sendable {
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

struct UserInfoResponseDTO: Decodable, Sendable {
    let userID: String
    let nick: String
    let profileImage: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case nick
        case profileImage
    }
}

struct TodayAuthorUserDTO: Decodable, Sendable {
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

struct TodayAuthorResponseDTO: Decodable, Sendable {
    let author: TodayAuthorUserDTO
    let filters: [TodayAuthorFilterDTO]?

    enum CodingKeys: String, CodingKey {
        case author, filters
    }
}

struct WithdrawResponseDTO: Decodable, Sendable {
    let userID: String
    let email: String
    let nick: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case nick
    }
}
