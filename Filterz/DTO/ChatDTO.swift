// ChatDTO.swift

import Foundation

// MARK: - Response DTOs

struct ChatRoomResponseDTO: Decodable {
    let roomId: String
    let createdAt: String
    let updatedAt: String
    let participants: [UserInfoResponseDTO]
    let lastChat: ChatResponseDTO?

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case createdAt, updatedAt, participants, lastChat
    }
}

struct ChatResponseDTO: Decodable {
    let chatId: String
    let roomId: String
    let content: String?
    let createdAt: String
    let updatedAt: String
    let sender: UserInfoResponseDTO
    let files: [String]

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case roomId = "room_id"
        case content, createdAt, updatedAt, sender, files
    }
}

struct ChatRoomListResponseDTO: Decodable {
    let data: [ChatRoomResponseDTO]
}

struct ChatListResponseDTO: Decodable {
    let data: [ChatResponseDTO]
}

struct ChatFileResponseDTO: Decodable {
    let files: [String]
}

// MARK: - Request DTOs

struct CreateChatRoomRequestDTO: Encodable {
    let opponentId: String

    enum CodingKeys: String, CodingKey {
        case opponentId = "opponent_id"
    }
}

struct SendMessageRequestDTO: Encodable {
    let content: String?
    let files: [String]?
}
