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
        var currentUserId: String = KeychainHelper.load(forKey: "userId") ?? ""
    }

    enum Action: Sendable {
        case onAppear
        case onDisappear
        case connectSocketRequested
        case networkStatusChanged(Bool)
        case reconnectSocketRequested
        case loadedLocal([ChatMessage])
        case syncedRemote([ChatMessage])
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
    @Dependency(\.networkStatusClient) var networkStatusClient
    @Dependency(\.continuousClock) var clock

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.hasStartedEffects else { return .none }
                state.hasStartedEffects = true
                state.isSyncing = true
                let roomId = state.room.roomId
                return .merge(
                    syncMessagesEffect(roomId: roomId, includeLocal: true),
                    connectSocketEffect(roomId: roomId),
                    observeNetworkEffect(roomId: roomId)
                )

            case .onDisappear:
                let roomId = state.room.roomId
                state.hasStartedEffects = false
                state.isSocketConnected = false
                state.isReconnectingSocket = false
                return .merge(
                    .cancel(id: socketCancelID(roomId)),
                    .cancel(id: networkCancelID(roomId)),
                    .cancel(id: reconnectCancelID(roomId)),
                    .cancel(id: syncCancelID(roomId)),
                    .run { _ in await chatSocketClient.disconnect() }
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
                return .concatenate(
                    .cancel(id: socketCancelID(roomId)),
                    .run { send in
                        while !Task.isCancelled {
                            await chatSocketClient.disconnect()
                            do {
                                let local = try await chatLocalStore.fetchMessages(roomId)
                                let nextParam = local.last?.createdAt.iso8601UTC
                                let remote = try await chatClient.getMessages(roomId, nextParam)
                                if !remote.isEmpty {
                                    try await chatLocalStore.upsertMessages(remote, roomId)
                                }
                                let merged = try await chatLocalStore.fetchMessages(roomId)
                                await send(.syncedRemote(merged))
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
                state.isReconnectingSocket = false
                let roomId = state.room.roomId
                return .merge(
                    .cancel(id: reconnectCancelID(roomId)),
                    syncMessagesEffect(roomId: roomId, includeLocal: false, reportsFailure: false)
                )

            case .socketEvent(.disconnected):
                state.isSocketConnected = false
                guard state.hasStartedEffects else { return .none }
                return .send(.reconnectSocketRequested)

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
                state.isReconnectingSocket = false
                return .merge(
                    .cancel(id: reconnectCancelID(state.room.roomId)),
                    .run { _ in await chatSocketClient.disconnect() }
                )

            case .socketEvent(.error(let message)):
                state.isSocketConnected = false
                guard state.hasStartedEffects else {
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
                return .none

            case .sendResponse(.failure(let error)):
                state.isSending = false
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
                state.errorMessage = "PDF를 열 수 없습니다."
                return .none

            case .pdfPreviewDismissed:
                state.pdfPreviewURL = nil
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
            if !remote.isEmpty {
                try await chatLocalStore.upsertMessages(remote, roomId)
            }
            let merged = try await chatLocalStore.fetchMessages(roomId)
            await send(.syncedRemote(merged))
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
