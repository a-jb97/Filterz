import Foundation

struct PickedImage: Equatable, Sendable, Identifiable {
    let id: UUID
    var thumbnail: Data
    var uploadData: Data?

    init(thumbnail: Data, uploadData: Data? = nil) {
        self.id = UUID()
        self.thumbnail = thumbnail
        self.uploadData = uploadData
    }
}

struct PickedFile: Equatable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let data: Data

    init(name: String, data: Data) {
        self.id = UUID()
        self.name = name
        self.data = data
    }
}

struct ChatRoom: Equatable, Sendable, Identifiable {
    let roomId: String
    let createdAt: Date
    let updatedAt: Date
    let opponentUserId: String
    var opponentNick: String
    var opponentProfilePath: String?
    let lastMessageContent: String?
    let lastMessageAt: Date?
    let lastMessageSenderId: String?
    var lastSeenChatId: String?
    var lastSeenMessageAt: Date?
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

struct ChatOpponentInfo: Equatable, Sendable {
    let userId: String
    let nick: String
    let profilePath: String?
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
        self.lastSeenChatId = nil
        self.lastSeenMessageAt = nil
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
        self.lastSeenChatId = entity.lastSeenChatId
        self.lastSeenMessageAt = entity.lastSeenMessageAt
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

extension ChatMessage {
    var imageFiles: [String] {
        files.filter {
            ["jpg", "jpeg", "png", "gif"].contains(($0 as NSString).pathExtension.lowercased())
        }
    }
    var pdfFiles: [String] {
        files.filter { ($0 as NSString).pathExtension.lowercased() == "pdf" }
    }
}
