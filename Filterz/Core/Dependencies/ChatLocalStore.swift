import Foundation
import SwiftData
import ComposableArchitecture

@ModelActor
actor ChatLocalStoreActor {

    func fetchRooms() throws -> [ChatRoom] {
        let descriptor = FetchDescriptor<ChatRoomEntity>(
            predicate: #Predicate { !$0.isHidden },
            sortBy: [SortDescriptor(\.lastMessageAt, order: .reverse),
                     SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map(ChatRoom.init(entity:))
    }

    func upsertRooms(_ dtos: [ChatRoomResponseDTO], currentUserId: String) throws {
        for dto in dtos {
            let id = dto.roomId
            let descriptor = FetchDescriptor<ChatRoomEntity>(
                predicate: #Predicate { $0.roomId == id }
            )
            let existing = try modelContext.fetch(descriptor).first
            guard let opponent = dto.participants.first(where: { $0.userID != currentUserId })
                    ?? dto.participants.first else { continue }
            let createdAt = Date.parseUTCISO8601(dto.createdAt) ?? .now
            let updatedAt = Date.parseUTCISO8601(dto.updatedAt) ?? .now
            let lastContent: String?
            let lastAt: Date?
            let lastSenderId: String?
            if let last = dto.lastChat {
                lastContent = last.content ?? (last.files.isEmpty ? nil : "사진")
                lastAt = Date.parseUTCISO8601(last.createdAt)
                lastSenderId = last.sender.userID
            } else {
                lastContent = nil
                lastAt = nil
                lastSenderId = nil
            }

            if let entity = existing {
                entity.updatedAt = updatedAt
                entity.opponentUserId = opponent.userID
                entity.opponentNick = opponent.nick
                entity.opponentProfilePath = opponent.profileImage
                if let lastAt {
                    entity.lastMessageContent = lastContent
                    entity.lastMessageAt = lastAt
                    entity.lastMessageSenderId = lastSenderId
                }
            } else {
                let entity = ChatRoomEntity(
                    roomId: dto.roomId,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    opponentUserId: opponent.userID,
                    opponentNick: opponent.nick,
                    opponentProfilePath: opponent.profileImage,
                    lastMessageContent: lastContent,
                    lastMessageAt: lastAt,
                    lastMessageSenderId: lastSenderId
                )
                modelContext.insert(entity)
            }
        }
        try modelContext.save()
    }

    func fetchMessages(roomId: String) throws -> [ChatMessage] {
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { $0.roomId == roomId },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map(ChatMessage.init(entity:))
    }

    func upsertMessages(_ dtos: [ChatResponseDTO], roomId: String) throws {
        let roomDescriptor = FetchDescriptor<ChatRoomEntity>(
            predicate: #Predicate { $0.roomId == roomId }
        )
        let room = try modelContext.fetch(roomDescriptor).first

        var latest: (content: String?, at: Date, senderId: String)? = nil

        for dto in dtos {
            let id = dto.chatId
            let descriptor = FetchDescriptor<ChatMessageEntity>(
                predicate: #Predicate { $0.chatId == id }
            )
            let existing = try modelContext.fetch(descriptor).first
            let createdAt = Date.parseUTCISO8601(dto.createdAt) ?? .now
            let updatedAt = Date.parseUTCISO8601(dto.updatedAt) ?? createdAt

            if let entity = existing {
                entity.content = dto.content
                entity.updatedAt = updatedAt
                entity.files = dto.files
            } else {
                let entity = ChatMessageEntity(
                    chatId: dto.chatId,
                    roomId: dto.roomId,
                    content: dto.content,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    senderId: dto.sender.userID,
                    senderNick: dto.sender.nick,
                    senderProfilePath: dto.sender.profileImage,
                    files: dto.files,
                    room: room
                )
                modelContext.insert(entity)
            }

            if latest == nil || latest!.at < createdAt {
                latest = (dto.content ?? (dto.files.isEmpty ? nil : "사진"), createdAt, dto.sender.userID)
            }
        }

        if let room, let latest {
            if room.lastMessageAt == nil || room.lastMessageAt! < latest.at {
                room.lastMessageContent = latest.content
                room.lastMessageAt = latest.at
                room.lastMessageSenderId = latest.senderId
            }
        }

        try modelContext.save()
    }

    func hideRoom(roomId: String) throws {
        let descriptor = FetchDescriptor<ChatRoomEntity>(
            predicate: #Predicate { $0.roomId == roomId }
        )

        if let room = try modelContext.fetch(descriptor).first {
            room.isHidden = true
            try modelContext.save()
        }
    }

    func unhideRoom(roomId: String) throws {
        let descriptor = FetchDescriptor<ChatRoomEntity>(
            predicate: #Predicate { $0.roomId == roomId }
        )

        if let room = try modelContext.fetch(descriptor).first {
            room.isHidden = false
            try modelContext.save()
        }
    }

    func incrementUnreadCount(roomId: String, by count: Int = 1) throws {
        guard count > 0 else { return }
        let descriptor = FetchDescriptor<ChatRoomEntity>(
            predicate: #Predicate { $0.roomId == roomId }
        )

        if let room = try modelContext.fetch(descriptor).first {
            room.unreadCount += count
            try modelContext.save()
        }
    }

    func markRoomRead(roomId: String) throws {
        let descriptor = FetchDescriptor<ChatRoomEntity>(
            predicate: #Predicate { $0.roomId == roomId }
        )

        if let room = try modelContext.fetch(descriptor).first, room.unreadCount != 0 {
            room.unreadCount = 0
            try modelContext.save()
        }
    }
}

struct ChatLocalStore: Sendable {
    var fetchRooms: @Sendable () async throws -> [ChatRoom]
    var upsertRooms: @Sendable (_ dtos: [ChatRoomResponseDTO], _ currentUserId: String) async throws -> Void
    var fetchMessages: @Sendable (_ roomId: String) async throws -> [ChatMessage]
    var upsertMessages: @Sendable (_ dtos: [ChatResponseDTO], _ roomId: String) async throws -> Void
    var hideRoom: @Sendable (_ roomId: String) async throws -> Void
    var unhideRoom: @Sendable (_ roomId: String) async throws -> Void
    var incrementUnreadCount: @Sendable (_ roomId: String, _ count: Int) async throws -> Void
    var markRoomRead: @Sendable (_ roomId: String) async throws -> Void
}

extension ChatLocalStore: DependencyKey {
    static var liveValue: ChatLocalStore {
        let actor = ChatLocalStoreActor(modelContainer: ChatModelContainer.shared)
        return ChatLocalStore(
            fetchRooms: { try await actor.fetchRooms() },
            upsertRooms: { dtos, currentUserId in
                try await actor.upsertRooms(dtos, currentUserId: currentUserId)
            },
            fetchMessages: { roomId in
                try await actor.fetchMessages(roomId: roomId)
            },
            upsertMessages: { dtos, roomId in
                try await actor.upsertMessages(dtos, roomId: roomId)
            },
            hideRoom: { roomId in
                try await actor.hideRoom(roomId: roomId)
            },
            unhideRoom: { roomId in
                try await actor.unhideRoom(roomId: roomId)
            },
            incrementUnreadCount: { roomId, count in
                try await actor.incrementUnreadCount(roomId: roomId, by: count)
            },
            markRoomRead: { roomId in
                try await actor.markRoomRead(roomId: roomId)
            }
        )
    }

    static var testValue: ChatLocalStore {
        ChatLocalStore(
            fetchRooms: { [] },
            upsertRooms: { _, _ in },
            fetchMessages: { _ in [] },
            upsertMessages: { _, _ in },
            hideRoom: { _ in },
            unhideRoom: { _ in },
            incrementUnreadCount: { _, _ in },
            markRoomRead: { _ in }
        )
    }
}

extension DependencyValues {
    var chatLocalStore: ChatLocalStore {
        get { self[ChatLocalStore.self] }
        set { self[ChatLocalStore.self] = newValue }
    }
}
