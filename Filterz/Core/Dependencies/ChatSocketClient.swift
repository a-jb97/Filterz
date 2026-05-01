import Foundation
import ComposableArchitecture
import SocketIO

enum ChatSocketEvent: Sendable {
    case connected
    case disconnected
    case message(ChatMessage)
    case authError(String)
    case error(String)
}

private actor SocketBox {
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var continuation: AsyncStream<ChatSocketEvent>.Continuation?

    func connect(roomId: String) -> AsyncStream<ChatSocketEvent> {
        disconnectInternal()

        let stream = AsyncStream<ChatSocketEvent> { continuation in
            self.continuation = continuation

            guard let url = URL(string: "http://filter.sesac.kr:42598") else {
                continuation.yield(.error("Invalid socket URL"))
                continuation.finish()
                return
            }

            let mgr = SocketManager(
                socketURL: url,
                config: [
                    .compress,
                    .forceWebsockets(true),
                    .extraHeaders([
                        "SeSACKey": APIKey.apiKey,
                        "Authorization": APIKey.accessToken
                    ])
                ]
            )
            self.manager = mgr
            let nsSocket = mgr.socket(forNamespace: "/chats-\(roomId)")
            self.socket = nsSocket

            nsSocket.on(clientEvent: .connect) { [weak self] _, _ in
                Task { await self?.yield(.connected) }
            }

            nsSocket.on(clientEvent: .disconnect) { [weak self] _, _ in
                Task { await self?.yield(.disconnected) }
            }

            nsSocket.on(clientEvent: .error) { [weak self] data, _ in
                let message = data.first.map { "\($0)" } ?? "Unknown socket error"
                Task { await self?.yield(authOrError(from: message)) }
            }

            nsSocket.on("chat") { [weak self] data, _ in
                guard let raw = data.first else { return }
                Task { await self?.handleChatPayload(raw) }
            }

            nsSocket.connect()
        }
        return stream
    }

    func disconnect() {
        disconnectInternal()
    }

    private func disconnectInternal() {
        socket?.disconnect()
        socket = nil
        manager?.disconnect()
        manager = nil
        continuation?.finish()
        continuation = nil
    }

    private func yield(_ event: ChatSocketEvent) {
        continuation?.yield(event)
    }

    private func handleChatPayload(_ raw: Any) {
        do {
            let data = try JSONSerialization.data(withJSONObject: raw)
            let dto = try JSONDecoder().decode(ChatResponseDTO.self, from: data)
            if let message = ChatMessage(dto: dto) {
                continuation?.yield(.message(message))
            }
        } catch {
            if let dict = raw as? [String: Any], let msg = dict["message"] as? String {
                continuation?.yield(authOrError(from: msg))
            } else {
                continuation?.yield(.error("Failed to decode chat payload"))
            }
        }
    }
}

nonisolated private func authOrError(from message: String) -> ChatSocketEvent {
    let knownAuthErrors = [
        "This Service sesac_memolease only",
        "액세스 토큰이 만료되었습니다.",
        "인증할 수 없는 엑세스 토큰입니다.",
        "Forbidden"
    ]
    if knownAuthErrors.contains(where: { message.contains($0) }) {
        return .authError(message)
    }
    return .error(message)
}

struct ChatSocketClient: Sendable {
    var connect: @Sendable (_ roomId: String) async -> AsyncStream<ChatSocketEvent>
    var disconnect: @Sendable () async -> Void
}

extension ChatSocketClient: DependencyKey {
    static var liveValue: ChatSocketClient {
        let box = SocketBox()
        return ChatSocketClient(
            connect: { roomId in
                await box.connect(roomId: roomId)
            },
            disconnect: {
                await box.disconnect()
            }
        )
    }

    static var testValue: ChatSocketClient {
        ChatSocketClient(
            connect: { _ in AsyncStream { $0.finish() } },
            disconnect: { }
        )
    }
}

extension DependencyValues {
    var chatSocketClient: ChatSocketClient {
        get { self[ChatSocketClient.self] }
        set { self[ChatSocketClient.self] = newValue }
    }
}
