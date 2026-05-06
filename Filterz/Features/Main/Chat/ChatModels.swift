import Foundation

struct ChatRoom: Equatable, Sendable, Identifiable {
    let roomId: String
    let createdAt: Date
    let updatedAt: Date
    let opponentUserId: String
    let opponentNick: String
    let opponentProfilePath: String?
    let lastMessageContent: String?
    let lastMessageAt: Date?
    let lastMessageSenderId: String?
    var unreadCount: Int = 0

    var id: String { roomId }
}

struct ChatMessage: Equatable, Sendable, Identifiable {
    let chatId: String
    let roomId: String
    let content: String?
    let createdAt: Date
    let updatedAt: Date
    let senderId: String
    let senderNick: String
    let senderProfilePath: String?
    let files: [String]

    var id: String { chatId }
}

extension ChatRoom {
    nonisolated init?(dto: ChatRoomResponseDTO, currentUserId: String) {
        guard let opponent = dto.participants.first(where: { $0.userID != currentUserId })
                ?? dto.participants.first else { return nil }
        guard let created = Date.parseUTCISO8601(dto.createdAt),
              let updated = Date.parseUTCISO8601(dto.updatedAt) else { return nil }
        self.roomId = dto.roomId
        self.createdAt = created
        self.updatedAt = updated
        self.opponentUserId = opponent.userID
        self.opponentNick = opponent.nick
        self.opponentProfilePath = opponent.profileImage

        if let last = dto.lastChat, let lastDate = Date.parseUTCISO8601(last.createdAt) {
            self.lastMessageContent = last.content ?? (last.files.isEmpty ? nil : "사진")
            self.lastMessageAt = lastDate
            self.lastMessageSenderId = last.sender.userID
        } else {
            self.lastMessageContent = nil
            self.lastMessageAt = nil
            self.lastMessageSenderId = nil
        }
        self.unreadCount = 0
    }

    nonisolated init(entity: ChatRoomEntity) {
        self.roomId = entity.roomId
        self.createdAt = entity.createdAt
        self.updatedAt = entity.updatedAt
        self.opponentUserId = entity.opponentUserId
        self.opponentNick = entity.opponentNick
        self.opponentProfilePath = entity.opponentProfilePath
        self.lastMessageContent = entity.lastMessageContent
        self.lastMessageAt = entity.lastMessageAt
        self.lastMessageSenderId = entity.lastMessageSenderId
        self.unreadCount = entity.unreadCount
    }
}

extension ChatMessage {
    nonisolated init?(dto: ChatResponseDTO) {
        guard let created = Date.parseUTCISO8601(dto.createdAt),
              let updated = Date.parseUTCISO8601(dto.updatedAt) else { return nil }
        self.chatId = dto.chatId
        self.roomId = dto.roomId
        self.content = dto.content
        self.createdAt = created
        self.updatedAt = updated
        self.senderId = dto.sender.userID
        self.senderNick = dto.sender.nick
        self.senderProfilePath = dto.sender.profileImage
        self.files = dto.files
    }

    nonisolated init(entity: ChatMessageEntity) {
        self.chatId = entity.chatId
        self.roomId = entity.roomId
        self.content = entity.content
        self.createdAt = entity.createdAt
        self.updatedAt = entity.updatedAt
        self.senderId = entity.senderId
        self.senderNick = entity.senderNick
        self.senderProfilePath = entity.senderProfilePath
        self.files = entity.files
    }
}
