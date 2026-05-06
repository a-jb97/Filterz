import ComposableArchitecture
import Foundation

@Reducer
struct ChatRoomFeature {

    @ObservableState
    struct State: Equatable {
        struct ImagePreview: Equatable, Sendable {
            let paths: [String]
            let selectedIndex: Int
        }

        let room: ChatRoom
        var messages: IdentifiedArrayOf<ChatMessage> = []
        var draft: String = ""
        var pickedImages: [Data] = []
        var imagePreview: ImagePreview? = nil
        var isSending: Bool = false
        var isSyncing: Bool = false
        var isSocketConnected: Bool = false
        var errorMessage: String? = nil
        var currentUserId: String = KeychainHelper.load(forKey: "userId") ?? ""
    }

    enum Action: Sendable {
        case onAppear
        case onDisappear
        case loadedLocal([ChatMessage])
        case syncedRemote([ChatMessage])
        case syncFailed(String)
        case socketEvent(ChatSocketEvent)
        case draftChanged(String)
        case imagesPicked([Data])
        case sendTapped
        case sendResponse(Result<ChatMessage, any Error>)
        case pushNotificationFailed(String)
        case errorMessageDismissed
        case imageTapped(paths: [String], index: Int)
        case imagePreviewDismissed
        case opponentProfileTapped
        case messageProfileTapped(userId: String)
        case backTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case backTapped
            case userProfileTapped(userId: String)
        }
    }

    @Dependency(\.chatClient) var chatClient
    @Dependency(\.chatLocalStore) var chatLocalStore
    @Dependency(\.chatSocketClient) var chatSocketClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isSyncing else { return .none }
                state.isSyncing = true
                let roomId = state.room.roomId
                return .run { send in
                    let local = try await chatLocalStore.fetchMessages(roomId)
                    await send(.loadedLocal(local))

                    let nextParam = local.last?.createdAt.iso8601UTC
                    let remote = try await chatClient.getMessages(roomId, nextParam)
                    if !remote.isEmpty {
                        try await chatLocalStore.upsertMessages(remote, roomId)
                    }
                    let merged = try await chatLocalStore.fetchMessages(roomId)
                    await send(.syncedRemote(merged))

                    let stream = await chatSocketClient.connect(roomId)
                    for await event in stream {
                        await send(.socketEvent(event))
                    }
                } catch: { error, send in
                    await send(.syncFailed(error.localizedDescription))
                }
                .cancellable(id: "chatRoomSocket-\(roomId)", cancelInFlight: true)

            case .onDisappear:
                let roomId = state.room.roomId
                return .merge(
                    .cancel(id: "chatRoomSocket-\(roomId)"),
                    .run { _ in await chatSocketClient.disconnect() }
                )

            case .loadedLocal(let messages):
                state.messages = IdentifiedArray(uniqueElements: messages)
                return .none

            case .syncedRemote(let messages):
                state.isSyncing = false
                state.messages = IdentifiedArray(uniqueElements: messages)
                return .none

            case .syncFailed(let message):
                state.isSyncing = false
                state.errorMessage = message
                return .none

            case .socketEvent(.connected):
                state.isSocketConnected = true
                return .none

            case .socketEvent(.disconnected):
                state.isSocketConnected = false
                return .none

            case .socketEvent(.message(let message)):
                state.messages[id: message.id] = message
                let roomId = state.room.roomId
                return .run { _ in
                    let dto = ChatResponseDTO(
                        chatId: message.chatId,
                        roomId: message.roomId,
                        content: message.content,
                        createdAt: message.createdAt.iso8601UTC,
                        updatedAt: message.updatedAt.iso8601UTC,
                        sender: UserInfoResponseDTO(
                            userID: message.senderId,
                            nick: message.senderNick,
                            profileImage: message.senderProfilePath
                        ),
                        files: message.files
                    )
                    try? await chatLocalStore.upsertMessages([dto], roomId)
                }

            case .socketEvent(.authError(let message)):
                state.errorMessage = message
                state.isSocketConnected = false
                return .run { _ in await chatSocketClient.disconnect() }

            case .socketEvent(.error(let message)):
                state.errorMessage = message
                return .none

            case .draftChanged(let value):
                state.draft = value
                return .none

            case .imagesPicked(let datas):
                state.pickedImages = datas
                return .none

            case .sendTapped:
                guard !state.isSending else { return .none }
                let trimmed = state.draft.trimmingCharacters(in: .whitespacesAndNewlines)
                let images = state.pickedImages
                guard !trimmed.isEmpty || !images.isEmpty else { return .none }
                state.isSending = true
                state.errorMessage = nil
                let roomId = state.room.roomId
                let opponentUserId = state.room.opponentUserId
                let opponentNick = state.room.opponentNick
                let content: String? = trimmed.isEmpty ? nil : trimmed
                return .run { send in
                    do {
                        var filePaths: [String]? = nil
                        if !images.isEmpty {
                            filePaths = try await chatClient.uploadFiles(roomId, images)
                        }
                        let dto = try await chatClient.sendMessage(roomId, content, filePaths)
                        try? await chatLocalStore.upsertMessages([dto], roomId)
                        let pushBody = notificationBody(content: content, fileCount: filePaths?.count ?? 0)
                        do {
                            try await chatClient.sendPushNotification(
                                opponentUserId,
                                dto.sender.nick,
                                opponentNick,
                                pushBody
                            )
                        } catch {
                            await send(.pushNotificationFailed(error.localizedDescription))
                        }
                        if let message = ChatMessage(dto: dto) {
                            await send(.sendResponse(.success(message)))
                        }
                    } catch {
                        await send(.sendResponse(.failure(error)))
                    }
                }

            case .sendResponse(.success(let message)):
                state.isSending = false
                state.draft = ""
                state.pickedImages = []
                state.messages[id: message.id] = message
                return .none

            case .sendResponse(.failure(let error)):
                state.isSending = false
                state.errorMessage = error.localizedDescription
                return .none

            case .pushNotificationFailed(let message):
                state.errorMessage = "푸시 알림 전송 실패: \(message)"
                return .none

            case .errorMessageDismissed:
                state.errorMessage = nil
                return .none

            case .imageTapped(let paths, let index):
                guard paths.indices.contains(index) else { return .none }
                state.imagePreview = State.ImagePreview(paths: paths, selectedIndex: index)
                return .none

            case .imagePreviewDismissed:
                state.imagePreview = nil
                return .none

            case .opponentProfileTapped:
                return .send(.delegate(.userProfileTapped(userId: state.room.opponentUserId)))

            case .messageProfileTapped(let userId):
                return .send(.delegate(.userProfileTapped(userId: userId)))

            case .backTapped:
                return .send(.delegate(.backTapped))

            case .delegate:
                return .none
            }
        }
    }
}

nonisolated private func notificationBody(content: String?, fileCount: Int) -> String {
    if let content, !content.isEmpty {
        return content
    }
    if fileCount > 0 {
        return "사진을 보냈습니다."
    }
    return "새 메시지가 도착했습니다."
}
