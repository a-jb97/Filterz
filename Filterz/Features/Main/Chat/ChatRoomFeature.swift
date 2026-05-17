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

        var room: ChatRoom
        var messages: IdentifiedArrayOf<ChatMessage> = []
        var draft: String = ""
        var pickedImages: [PickedImage] = []
        var pickedFiles: [PickedFile] = []
        var attachmentAlert: String? = nil
        var pdfPreviewURL: URL? = nil
        var imagePreview: ImagePreview? = nil
        var isSending: Bool = false
        var isSyncing: Bool = false
        var isSocketConnected: Bool = false
        var isNetworkReachable: Bool = true
        var isReconnectingSocket: Bool = false
        var hasStartedEffects: Bool = false
        var errorMessage: String? = nil
        var errorTitle: String = "채팅 오류"
        var currentUserId: String = KeychainHelper.load(forKey: "userId") ?? ""
        var lastSeenChatId: String? = nil
        var lastSeenMessageAt: Date? = nil
        var initialScrollTargetId: String? = nil
        var shouldPreserveUnreadPosition: Bool = false
        var unreadSummaryMessages: [ChatMessage] = []
        var showsAISummaryButton: Bool = false
        var isAISummaryEnabled: Bool = true
        var didOfferSummaryForCurrentVisit: Bool = false
        var isSummarizing: Bool = false
        var summaryText: String? = nil
        var isSummarySheetPresented: Bool = false
    }

    enum Action: Sendable {
        case onAppear
        case onDisappear
        case connectSocketRequested
        case networkStatusChanged(Bool)
        case reconnectSocketRequested
        case loadedLocal([ChatMessage])
        case syncedRemote(
            messages: [ChatMessage],
            lastSeenChatId: String?,
            lastSeenMessageAt: Date?,
            opponentInfo: ChatOpponentInfo?
        )
        case syncFailed(String)
        case socketEvent(ChatSocketEvent)
        case draftChanged(String)
        case imagesPicked([PickedImage])
        case imageRemoved(Int)
        case imagePrepared(id: UUID, uploadData: Data, thumbnail: Data)
        case sendTapped
        case sendResponse(Result<ChatMessage, any Error>)
        case errorMessageDismissed
        case imageTapped(paths: [String], index: Int)
        case imagePreviewDismissed
        case filesPicked([PickedFile])
        case fileRemoved(Int)
        case attachmentAlertDismissed
        case invalidAttachmentDetected(String)
        case pdfTapped(path: String)
        case pdfPreviewDismissed
        case pdfDownloaded(Result<URL, any Error>)
        case aiSummaryButtonTapped
        case aiSummaryResponse(Result<String, any Error>)
        case summarySheetDismissed
        case latestMessagesReached
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
    @Dependency(\.chatSummaryClient) var chatSummaryClient
    @Dependency(\.userSettings) var userSettings
    @Dependency(\.networkStatusClient) var networkStatusClient
    @Dependency(\.continuousClock) var clock

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.hasStartedEffects else { return .none }
                state.hasStartedEffects = true
                state.isSyncing = true
                state.isAISummaryEnabled = userSettings.isAISummaryEnabled()
                let roomId = state.room.roomId
                let currentUserId = state.currentUserId
                return .merge(
                    syncMessagesEffect(roomId: roomId, currentUserId: currentUserId, includeLocal: true),
                    connectSocketEffect(roomId: roomId),
                    observeNetworkEffect(roomId: roomId)
                )

            case .onDisappear:
                let roomId = state.room.roomId
                let lastMessage = state.messages.last
                state.hasStartedEffects = false
                state.isSocketConnected = false
                state.isReconnectingSocket = false
                state.didOfferSummaryForCurrentVisit = false
                return .merge(
                    .cancel(id: socketCancelID(roomId)),
                    .cancel(id: networkCancelID(roomId)),
                    .cancel(id: reconnectCancelID(roomId)),
                    .cancel(id: syncCancelID(roomId)),
                    .cancel(id: summaryCancelID(roomId)),
                    .run { _ in
                        if let lastMessage {
                            try? await chatLocalStore.markLastSeen(
                                roomId,
                                lastMessage.chatId,
                                lastMessage.createdAt
                            )
                        }
                        await chatSocketClient.disconnect()
                    }
                )

            case .connectSocketRequested:
                return connectSocketEffect(roomId: state.room.roomId)

            case .networkStatusChanged(let isReachable):
                let wasReachable = state.isNetworkReachable
                state.isNetworkReachable = isReachable
                guard isReachable,
                      !wasReachable,
                      state.hasStartedEffects,
                      !state.isSocketConnected,
                      !state.isReconnectingSocket else {
                    return .none
                }
                return .send(.reconnectSocketRequested)

            case .reconnectSocketRequested:
                guard !state.isReconnectingSocket else { return .none }
                state.isReconnectingSocket = true
                let roomId = state.room.roomId
                let currentUserId = state.currentUserId
                return .concatenate(
                    .cancel(id: socketCancelID(roomId)),
                    .run { send in
                        while !Task.isCancelled {
                            await chatSocketClient.disconnect()
                            do {
                                let local = try await chatLocalStore.fetchMessages(roomId)
                                let nextParam = local.last?.createdAt.iso8601UTC
                                let remote = try await chatClient.getMessages(roomId, nextParam)
                                let opponentInfo = latestOpponentInfo(from: remote, currentUserId: currentUserId)
                                if !remote.isEmpty {
                                    try await chatLocalStore.upsertMessages(remote, roomId)
                                }
                                let merged = try await chatLocalStore.fetchMessages(roomId)
                                let lastSeen = try await chatLocalStore.fetchLastSeen(roomId)
                                await send(.syncedRemote(
                                    messages: merged,
                                    lastSeenChatId: lastSeen.chatId,
                                    lastSeenMessageAt: lastSeen.messageAt,
                                    opponentInfo: opponentInfo
                                ))
                            } catch {
                                // Keep retrying silently while the room is visible.
                            }

                            await send(.connectSocketRequested)
                            try await clock.sleep(for: .seconds(3))
                        }
                    }
                    .cancellable(id: reconnectCancelID(roomId), cancelInFlight: true)
                )

            case .loadedLocal(let messages):
                state.messages = IdentifiedArray(uniqueElements: messages)
                return .none

            case let .syncedRemote(messages, lastSeenChatId, lastSeenMessageAt, opponentInfo):
                state.isSyncing = false
                state.messages = IdentifiedArray(uniqueElements: messages)
                updateOpponentInfo(opponentInfo, state: &state)
                state.lastSeenChatId = lastSeenChatId
                state.lastSeenMessageAt = lastSeenMessageAt
                state.initialScrollTargetId = initialScrollTarget(
                    messages: messages,
                    lastSeenChatId: lastSeenChatId,
                    lastSeenMessageAt: lastSeenMessageAt
                )
                let unread = unreadOpponentMessages(
                    messages: messages,
                    after: lastSeenMessageAt,
                    currentUserId: state.currentUserId
                )
                state.unreadSummaryMessages = unread
                let shouldOfferSummary = state.isAISummaryEnabled && !unread.isEmpty && !state.didOfferSummaryForCurrentVisit
                state.showsAISummaryButton = shouldOfferSummary
                if shouldOfferSummary {
                    state.didOfferSummaryForCurrentVisit = true
                }
                state.shouldPreserveUnreadPosition = !unread.isEmpty && state.initialScrollTargetId != nil
                return .none

            case .syncFailed(let message):
                state.isSyncing = false
                state.errorTitle = "채팅 동기화 실패"
                state.errorMessage = message
                return .none

            case .socketEvent(.connected):
                state.isSocketConnected = true
                state.isReconnectingSocket = false
                let roomId = state.room.roomId
                return .merge(
                    .cancel(id: reconnectCancelID(roomId)),
                    syncMessagesEffect(
                        roomId: roomId,
                        currentUserId: state.currentUserId,
                        includeLocal: false,
                        reportsFailure: false
                    )
                )

            case .socketEvent(.disconnected):
                state.isSocketConnected = false
                guard state.hasStartedEffects else { return .none }
                return .send(.reconnectSocketRequested)

            case .socketEvent(.message(let message)):
                state.messages[id: message.id] = message
                updateOpponentInfo(from: [message], state: &state)
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
                state.errorTitle = "채팅 연결 실패"
                state.errorMessage = message
                state.isSocketConnected = false
                state.isReconnectingSocket = false
                return .merge(
                    .cancel(id: reconnectCancelID(state.room.roomId)),
                    .run { _ in await chatSocketClient.disconnect() }
                )

            case .socketEvent(.error(let message)):
                state.isSocketConnected = false
                guard state.hasStartedEffects else {
                    state.errorTitle = "채팅 연결 실패"
                    state.errorMessage = message
                    return .none
                }
                return .send(.reconnectSocketRequested)

            case .draftChanged(let value):
                state.draft = value
                return .none

            case .imagesPicked(let datas):
                state.pickedImages = datas
                return .none

            case .imageRemoved(let index):
                guard state.pickedImages.indices.contains(index) else { return .none }
                state.pickedImages.remove(at: index)
                return .none

            case .imagePrepared(let id, let uploadData, let thumbnail):
                guard let index = state.pickedImages.firstIndex(where: { $0.id == id }) else {
                    return .none
                }
                state.pickedImages[index].uploadData = uploadData
                state.pickedImages[index].thumbnail = thumbnail
                return .none

            case .sendTapped:
                guard !state.isSending else { return .none }
                let trimmed = state.draft.trimmingCharacters(in: .whitespacesAndNewlines)
                let imageUploadables = state.pickedImages.compactMap(\.uploadData)
                    .enumerated()
                    .map { i, data in UploadableFile(data: data, mimeType: "image/jpeg", fileName: "image\(i).jpg") }
                let fileUploadables = state.pickedFiles
                    .enumerated()
                    .map { i, file in UploadableFile(data: file.data, mimeType: "application/pdf", fileName: "doc\(i).pdf") }
                let allFiles = imageUploadables + fileUploadables
                guard !trimmed.isEmpty || !allFiles.isEmpty else { return .none }
                state.isSending = true
                state.errorTitle = "메시지 전송 실패"
                state.errorMessage = nil
                let roomId = state.room.roomId
                let content: String? = trimmed.isEmpty ? nil : trimmed
                return .run { send in
                    do {
                        var filePaths: [String]? = nil
                        if !allFiles.isEmpty {
                            filePaths = try await chatClient.uploadFiles(roomId, allFiles)
                        }
                        let dto = try await chatClient.sendMessage(roomId, content, filePaths)
                        try? await chatLocalStore.upsertMessages([dto], roomId)
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
                state.pickedFiles = []
                state.messages[id: message.id] = message
                state.shouldPreserveUnreadPosition = false
                return .none

            case .sendResponse(.failure(let error)):
                state.isSending = false
                state.errorTitle = "메시지 전송 실패"
                state.errorMessage = error.localizedDescription
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

            case .filesPicked(let files):
                state.pickedFiles = files
                return .none

            case .fileRemoved(let index):
                guard state.pickedFiles.indices.contains(index) else { return .none }
                state.pickedFiles.remove(at: index)
                return .none

            case .attachmentAlertDismissed:
                state.attachmentAlert = nil
                return .none

            case .invalidAttachmentDetected(let message):
                state.attachmentAlert = message
                return .none

            case .pdfTapped(let path):
                return .run { send in
                    do {
                        let url = try await downloadPDFToTemp(path: path)
                        await send(.pdfDownloaded(.success(url)))
                    } catch {
                        await send(.pdfDownloaded(.failure(error)))
                    }
                }

            case .pdfDownloaded(.success(let url)):
                state.pdfPreviewURL = url
                return .none

            case .pdfDownloaded(.failure):
                state.errorTitle = "파일 열기 실패"
                state.errorMessage = "PDF를 열 수 없습니다."
                return .none

            case .pdfPreviewDismissed:
                state.pdfPreviewURL = nil
                return .none

            case .aiSummaryButtonTapped:
                guard !state.isSummarizing else { return .none }
                guard state.isAISummaryEnabled else {
                    state.showsAISummaryButton = false
                    return .none
                }
                guard !state.unreadSummaryMessages.isEmpty else {
                    state.showsAISummaryButton = false
                    return .none
                }
                state.isSummarizing = true
                state.errorTitle = "AI 요약 실패"
                state.errorMessage = nil
                let messages = state.unreadSummaryMessages.map {
                    ChatSummaryMessage(
                        senderNick: $0.senderNick,
                        content: $0.content,
                        files: $0.files,
                        createdAt: $0.createdAt
                    )
                }
                return .run { send in
                    do {
                        let summary = try await chatSummaryClient.summarize(messages)
                        await send(.aiSummaryResponse(.success(summary)))
                    } catch {
                        await send(.aiSummaryResponse(.failure(error)))
                    }
                }
                .cancellable(id: summaryCancelID(state.room.roomId), cancelInFlight: true)

            case .aiSummaryResponse(.success(let summary)):
                state.isSummarizing = false
                state.summaryText = summary
                state.isSummarySheetPresented = true
                state.showsAISummaryButton = false
                return .none

            case .aiSummaryResponse(.failure(let error)):
                state.isSummarizing = false
                state.errorTitle = "AI 요약 실패"
                state.errorMessage = error.localizedDescription
                return .none

            case .summarySheetDismissed:
                state.isSummarySheetPresented = false
                return .none

            case .latestMessagesReached:
                guard state.showsAISummaryButton else { return .none }
                state.showsAISummaryButton = false
                state.shouldPreserveUnreadPosition = false
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

    private func syncMessagesEffect(
        roomId: String,
        currentUserId: String,
        includeLocal: Bool,
        reportsFailure: Bool = true
    ) -> Effect<Action> {
        .run { send in
            let local = try await chatLocalStore.fetchMessages(roomId)
            if includeLocal {
                await send(.loadedLocal(local))
            }

            let nextParam = local.last?.createdAt.iso8601UTC
            let remote = try await chatClient.getMessages(roomId, nextParam)
            let opponentInfo = latestOpponentInfo(from: remote, currentUserId: currentUserId)
            if !remote.isEmpty {
                try await chatLocalStore.upsertMessages(remote, roomId)
            }
            let merged = try await chatLocalStore.fetchMessages(roomId)
            let lastSeen = try await chatLocalStore.fetchLastSeen(roomId)
            await send(.syncedRemote(
                messages: merged,
                lastSeenChatId: lastSeen.chatId,
                lastSeenMessageAt: lastSeen.messageAt,
                opponentInfo: opponentInfo
            ))
        } catch: { error, send in
            if reportsFailure {
                await send(.syncFailed(error.localizedDescription))
            }
        }
        .cancellable(id: syncCancelID(roomId), cancelInFlight: true)
    }

    private func connectSocketEffect(roomId: String) -> Effect<Action> {
        .run { send in
            let stream = await chatSocketClient.connect(roomId)
            for await event in stream {
                await send(.socketEvent(event))
            }
        }
        .cancellable(id: socketCancelID(roomId), cancelInFlight: true)
    }

    private func observeNetworkEffect(roomId: String) -> Effect<Action> {
        let stream = networkStatusClient.observe()
        return .run { send in
            for await isReachable in stream {
                await send(.networkStatusChanged(isReachable))
            }
        }
        .cancellable(id: networkCancelID(roomId), cancelInFlight: true)
    }

    private func syncCancelID(_ roomId: String) -> String {
        "chatRoomSync-\(roomId)"
    }

    private func socketCancelID(_ roomId: String) -> String {
        "chatRoomSocket-\(roomId)"
    }

    private func networkCancelID(_ roomId: String) -> String {
        "chatRoomNetwork-\(roomId)"
    }

    private func reconnectCancelID(_ roomId: String) -> String {
        "chatRoomReconnect-\(roomId)"
    }

    private func summaryCancelID(_ roomId: String) -> String {
        "chatRoomSummary-\(roomId)"
    }

    private func initialScrollTarget(
        messages: [ChatMessage],
        lastSeenChatId: String?,
        lastSeenMessageAt: Date?
    ) -> String? {
        guard let lastSeenMessageAt else { return nil }
        if let lastSeenChatId, messages.contains(where: { $0.id == lastSeenChatId }) {
            return lastSeenChatId
        }
        return messages.last(where: { $0.createdAt <= lastSeenMessageAt })?.id
    }

    private func unreadOpponentMessages(
        messages: [ChatMessage],
        after lastSeenMessageAt: Date?,
        currentUserId: String
    ) -> [ChatMessage] {
        guard let lastSeenMessageAt else { return [] }
        return messages.filter {
            $0.senderId != currentUserId && $0.createdAt > lastSeenMessageAt
        }
    }

    private func updateOpponentInfo(from messages: [ChatMessage], state: inout State) {
        guard let latestOpponentMessage = messages.last(where: { $0.senderId == state.room.opponentUserId }) else {
            return
        }
        state.room.opponentNick = latestOpponentMessage.senderNick
        state.room.opponentProfilePath = latestOpponentMessage.senderProfilePath
    }

    private func updateOpponentInfo(_ opponentInfo: ChatOpponentInfo?, state: inout State) {
        guard let opponentInfo, opponentInfo.userId == state.room.opponentUserId else { return }
        state.room.opponentNick = opponentInfo.nick
        state.room.opponentProfilePath = opponentInfo.profilePath
    }

    nonisolated private func latestOpponentInfo(
        from dtos: [ChatResponseDTO],
        currentUserId: String
    ) -> ChatOpponentInfo? {
        dtos.last(where: { $0.sender.userID != currentUserId }).map {
            ChatOpponentInfo(
                userId: $0.sender.userID,
                nick: $0.sender.nick,
                profilePath: $0.sender.profileImage
            )
        }
    }

    private func downloadPDFToTemp(path: String) async throws -> URL {
        let urlString = path.hasPrefix("http") ? path : APIKey.baseURL + "/" + path
        guard let fullURL = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: fullURL)
        request.setValue(APIKey.apiKey, forHTTPHeaderField: "SeSACKey")
        request.setValue(APIKey.accessToken, forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let fileName = (path as NSString).lastPathComponent
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL)
        return tempURL
    }
}
