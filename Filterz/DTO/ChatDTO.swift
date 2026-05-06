// ChatDTO.swift

import Foundation

// MARK: - Response DTOs

nonisolated struct ChatRoomResponseDTO: Decodable, Sendable {
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

nonisolated struct ChatResponseDTO: Decodable, Sendable {
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

nonisolated struct ChatRoomListResponseDTO: Decodable, Sendable {
    let data: [ChatRoomResponseDTO]
}

nonisolated struct ChatListResponseDTO: Decodable, Sendable {
    let data: [ChatResponseDTO]
}

nonisolated struct ChatFileResponseDTO: Decodable, Sendable {
    let files: [String]
}

// MARK: - Request DTOs

nonisolated struct CreateChatRoomRequestDTO: Encodable, Sendable {
    let opponentId: String

    enum CodingKeys: String, CodingKey {
        case opponentId = "opponent_id"
    }
}

nonisolated struct SendMessageRequestDTO: Encodable, Sendable {
    let content: String
    let files: [String]
}
