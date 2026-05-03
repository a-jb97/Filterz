import ComposableArchitecture
import Foundation

struct UserClient: Sendable {
    var getTodayAuthor: @Sendable () async throws -> TodayAuthorResponseDTO
    var searchUsers: @Sendable (_ nick: String) async throws -> [UserInfoResponseDTO]
}

extension UserClient: DependencyKey {
    static var liveValue: UserClient {
        UserClient(
            getTodayAuthor: {
                try await NetworkManager.shared.request(.getTodayAuthor)
            },
            searchUsers: { nick in
                let response: UserSearchResponseDTO = try await NetworkManager.shared.request(.searchUsers(nick: nick))
                return response.data
            }
        )
    }

    static var testValue: UserClient {
        let mockAuthor = TodayAuthorUserDTO(
            userID: "test-user",
            nick: "테스트작가",
            name: "Test Artist",
            profileImage: nil,
            introduction: "\"테스트 인용구\"",
            description: "테스트 작가 소개입니다.",
            hashTags: ["테스트", "작가"]
        )
        let mockFilters = [
            TodayAuthorFilterDTO(filterId: "f1", files: []),
            TodayAuthorFilterDTO(filterId: "f2", files: [])
        ]
        return UserClient(
            getTodayAuthor: {
                TodayAuthorResponseDTO(author: mockAuthor, filters: mockFilters)
            },
            searchUsers: { _ in [] }
        )
    }
}

extension DependencyValues {
    var userClient: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}
