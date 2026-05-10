import ComposableArchitecture
import Foundation
import FoundationModels

struct ChatSummaryMessage: Equatable, Sendable {
    let senderNick: String
    let content: String?
    let files: [String]
    let createdAt: Date
}

enum ChatSummaryError: Error, LocalizedError {
    case unavailable
    case emptyMessages
    case contentRejected

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "AI 요약을 사용할 수 없습니다."
        case .emptyMessages:
            "요약할 새 메시지가 없습니다."
        case .contentRejected:
            "Apple Intelligence가 이 대화 내용을 안전하지 않은 콘텐츠로 판단해 요약하지 못했습니다."
        }
    }
}

struct ChatSummaryClient: Sendable {
    var isAvailable: @Sendable () async -> Bool
    var summarize: @Sendable (_ messages: [ChatSummaryMessage]) async throws -> String
}

extension ChatSummaryClient: DependencyKey {
    static var liveValue: ChatSummaryClient {
        ChatSummaryClient(
            isAvailable: {
                guard #available(iOS 26.0, *) else { return false }
                return SystemLanguageModel.default.isAvailable
            },
            summarize: { messages in
                guard #available(iOS 26.0, *) else {
                    throw ChatSummaryError.unavailable
                }
                guard SystemLanguageModel.default.isAvailable else {
                    throw ChatSummaryError.unavailable
                }
                let lines = messages.map(summaryLine(for:))
                    .filter { !$0.isEmpty }
                guard !lines.isEmpty else {
                    throw ChatSummaryError.emptyMessages
                }

                let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
                let session = LanguageModelSession(
                    model: model,
                    instructions: """
                    너는 채팅방의 읽지 않은 상대 메시지를 간결하게 요약하는 도우미야.
                    한국어로 답하고, 사용자가 바로 대화 맥락을 파악할 수 있게 핵심만 정리해.
                    과장하거나 메시지에 없는 내용을 추가하지 마.
                    """
                )
                let prompt = """
                아래는 사용자가 아직 확인하지 않은 채팅 메시지야.
                핵심 내용을 2~4개의 짧은 bullet로 요약하고, 마지막 줄에는 필요한 응답이나 액션이 있으면 한 문장으로 알려줘.

                \(lines.joined(separator: "\n"))
                """
                do {
                    let response = try await session.respond(
                        to: prompt,
                        options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 280)
                    )
                    return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                } catch LanguageModelSession.GenerationError.guardrailViolation {
                    throw ChatSummaryError.contentRejected
                } catch LanguageModelSession.GenerationError.refusal {
                    throw ChatSummaryError.contentRejected
                }
            }
        )
    }

    static var testValue: ChatSummaryClient {
        ChatSummaryClient(
            isAvailable: { false },
            summarize: { _ in "요약 결과" }
        )
    }
}

extension DependencyValues {
    var chatSummaryClient: ChatSummaryClient {
        get { self[ChatSummaryClient.self] }
        set { self[ChatSummaryClient.self] = newValue }
    }
}

nonisolated private func summaryLine(for message: ChatSummaryMessage) -> String {
    let body = message.content?.trimmingCharacters(in: .whitespacesAndNewlines)
    let attachmentText = attachmentDescription(for: message.files)
    let content = [body, attachmentText]
        .compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        .joined(separator: " ")
    guard !content.isEmpty else { return "" }
    return "- \(message.createdAt.chatTimeDisplay) \(message.senderNick): \(content)"
}

nonisolated private func attachmentDescription(for files: [String]) -> String? {
    guard !files.isEmpty else { return nil }
    let imageCount = files.filter {
        ["jpg", "jpeg", "png", "gif"].contains(($0 as NSString).pathExtension.lowercased())
    }.count
    let pdfCount = files.filter {
        ($0 as NSString).pathExtension.lowercased() == "pdf"
    }.count
    var parts: [String] = []
    if imageCount > 0 {
        parts.append("이미지 \(imageCount)개 첨부")
    }
    if pdfCount > 0 {
        parts.append("PDF \(pdfCount)개 첨부")
    }
    let otherCount = files.count - imageCount - pdfCount
    if otherCount > 0 {
        parts.append("파일 \(otherCount)개 첨부")
    }
    return parts.isEmpty ? nil : "(\(parts.joined(separator: ", ")))"
}
