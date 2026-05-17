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

nonisolated struct EditMyProfileRequestDTO: Encodable, Sendable {
    let nick: String?
    let name: String?
    let introduction: String?
    let phoneNum: String?
    let profileImage: String?
    let hashTags: [String]?
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
    let phoneNum: String?
    let hashTags: [String]

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case nick
        case name
        case introduction
        case profileImage
        case phoneNum
        case hashTags
    }
}

typealias EditMyProfileResponseDTO = MyInfoResponseDTO

nonisolated struct UserProfileResponseDTO: Decodable, Sendable {
    let userID: String
    let nick: String
    let name: String?
    let introduction: String?
    let profileImage: String?
    let hashTags: [String]

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case nick
        case name
        case introduction
        case profileImage
        case hashTags
    }
}

nonisolated struct UserInfoResponseDTO: Decodable, Sendable {
    let userID: String
    let nick: String
    let name: String?
    let introduction: String?
    let profileImage: String?
    let hashTags: [String]?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case nick
        case name
        case introduction
        case profileImage
        case hashTags
    }

    init(
        userID: String,
        nick: String,
        name: String? = nil,
        introduction: String? = nil,
        profileImage: String? = nil,
        hashTags: [String]? = nil
    ) {
        self.userID = userID
        self.nick = nick
        self.name = name
        self.introduction = introduction
        self.profileImage = profileImage
        self.hashTags = hashTags
    }
}

nonisolated struct UserSearchResponseDTO: Decodable, Sendable {
    let data: [UserInfoResponseDTO]
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
