import Foundation
import SwiftData

enum ChatModelContainer {
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: ChatRoomEntity.self, ChatMessageEntity.self)
        } catch {
            fatalError("Failed to create ChatModelContainer: \(error)")
        }
    }()
}
