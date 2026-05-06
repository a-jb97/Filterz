import Foundation
import ComposableArchitecture

struct ChatClient: Sendable {
    var getChatRooms: @Sendable () async throws -> [ChatRoomResponseDTO]
    var getMessages: @Sendable (_ roomId: String, _ next: String?) async throws -> [ChatResponseDTO]
    var sendMessage: @Sendable (_ roomId: String, _ content: String?, _ files: [String]?) async throws -> ChatResponseDTO
    var createChatRoom: @Sendable (_ opponentId: String) async throws -> ChatRoomResponseDTO
    var uploadFiles: @Sendable (_ roomId: String, _ images: [Data]) async throws -> [String]
    var sendPushNotification: @Sendable (_ userId: String, _ title: String, _ subtitle: String?, _ body: String) async throws -> Void
}

extension ChatClient: DependencyKey {
    static var liveValue: ChatClient {
        ChatClient(
            getChatRooms: {
                let response: ChatRoomListResponseDTO = try await NetworkManager.shared.request(.getChatRooms)
                return response.data
            },
            getMessages: { roomId, next in
                let response: ChatListResponseDTO = try await NetworkManager.shared.request(
                    .getChatMessages(roomId: roomId, next: next)
                )
                return response.data
            },
            sendMessage: { roomId, content, files in
                try await NetworkManager.shared.request(
                    .sendMessage(
                        roomId: roomId,
                        query: SendMessageRequestDTO(
                            content: content ?? "",
                            files: files ?? []
                        )
                    )
                )
            },
            createChatRoom: { opponentId in
                try await NetworkManager.shared.request(
                    .createChatRoom(query: CreateChatRoomRequestDTO(opponentId: opponentId))
                )
            },
            uploadFiles: { roomId, images in
                let response: ChatFileResponseDTO = try await NetworkManager.shared.uploadFiles(
                    .sendChatFiles(roomId: roomId), images: images
                )
                return response.files
            },
            sendPushNotification: { userId, title, subtitle, body in
                try await NetworkManager.shared.requestVoid(
                    .sendPushNotification(
                        query: PushNotificationRequestDTO(
                            userId: userId,
                            title: title,
                            subtitle: subtitle,
                            body: body
                        )
                    )
                )
            }
        )
    }

    static var testValue: ChatClient {
        ChatClient(
            getChatRooms: { [] },
            getMessages: { _, _ in [] },
            sendMessage: { _, _, _ in
                ChatResponseDTO(
                    chatId: UUID().uuidString,
                    roomId: "",
                    content: nil,
                    createdAt: Date().iso8601UTC,
                    updatedAt: Date().iso8601UTC,
                    sender: UserInfoResponseDTO(userID: "test", nick: "tester", profileImage: nil),
                    files: []
                )
            },
            createChatRoom: { _ in
                ChatRoomResponseDTO(
                    roomId: UUID().uuidString,
                    createdAt: Date().iso8601UTC,
                    updatedAt: Date().iso8601UTC,
                    participants: [],
                    lastChat: nil
                )
            },
            uploadFiles: { _, _ in [] },
            sendPushNotification: { _, _, _, _ in }
        )
    }
}

extension DependencyValues {
    var chatClient: ChatClient {
        get { self[ChatClient.self] }
        set { self[ChatClient.self] = newValue }
    }
}
