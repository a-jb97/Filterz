import Foundation
import SwiftData

@Model
final class ChatMessageEntity {
    @Attribute(.unique) var chatId: String
    var roomId: String
    var content: String?
    var createdAt: Date
    var updatedAt: Date
    var senderId: String
    var senderNick: String
    var senderProfilePath: String?
    var files: [String]
    var room: ChatRoomEntity?

    init(
        chatId: String,
        roomId: String,
        content: String?,
        createdAt: Date,
        updatedAt: Date,
        senderId: String,
        senderNick: String,
        senderProfilePath: String?,
        files: [String],
        room: ChatRoomEntity? = nil
    ) {
        self.chatId = chatId
        self.roomId = roomId
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.senderId = senderId
        self.senderNick = senderNick
        self.senderProfilePath = senderProfilePath
        self.files = files
        self.room = room
    }
}
