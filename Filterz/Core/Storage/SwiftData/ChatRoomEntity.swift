import Foundation
import SwiftData

@Model
final class ChatRoomEntity {
    @Attribute(.unique) var roomId: String
    var ownerUserId: String = ""
    var createdAt: Date
    var updatedAt: Date
    var opponentUserId: String
    var opponentNick: String
    var opponentProfilePath: String?
    var lastMessageContent: String?
    var lastMessageAt: Date?
    var lastMessageSenderId: String?
    var lastSeenChatId: String?
    var lastSeenMessageAt: Date?
    var unreadCount: Int = 0
    var isHidden: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \ChatMessageEntity.room)
    var messages: [ChatMessageEntity] = []

    init(
        roomId: String,
        ownerUserId: String,
        createdAt: Date,
        updatedAt: Date,
        opponentUserId: String,
        opponentNick: String,
        opponentProfilePath: String?,
        lastMessageContent: String?,
        lastMessageAt: Date?,
        lastMessageSenderId: String?
    ) {
        self.roomId = roomId
        self.ownerUserId = ownerUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.opponentUserId = opponentUserId
        self.opponentNick = opponentNick
        self.opponentProfilePath = opponentProfilePath
        self.lastMessageContent = lastMessageContent
        self.lastMessageAt = lastMessageAt
        self.lastMessageSenderId = lastMessageSenderId
        self.unreadCount = 0
        self.isHidden = false
    }
}
