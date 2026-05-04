import ComposableArchitecture
import Foundation

struct UserClient: Sendable {
    var myInfo: @Sendable () async throws -> MyInfoResponseDTO
    var editMyProfile: @Sendable (_ query: EditMyProfileRequestDTO) async throws -> EditMyProfileResponseDTO
    var uploadProfileImage: @Sendable (_ image: Data) async throws -> String?
    var getTodayAuthor: @Sendable () async throws -> TodayAuthorResponseDTO
    var searchUsers: @Sendable (_ nick: String) async throws -> [UserInfoResponseDTO]
}

extension UserClient: DependencyKey {
    static var liveValue: UserClient {
        UserClient(
            myInfo: {
                try await NetworkManager.shared.request(.myInfo)
            },
            editMyProfile: { query in
                try await NetworkManager.shared.request(.editMyProfile(query: query))
            },
            uploadProfileImage: { image in
                let response: FileResponseDTO = try await NetworkManager.shared.uploadFiles(.uploadFile, images: [image])
                return response.files.first
            },
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
        let mockInfo = MyInfoResponseDTO(
            userID: "test-user",
            email: "test@filterz.com",
            nick: "테스트유저",
            name: nil,
            introduction: "테스트 소개입니다.",
            profileImage: nil,
            phoneNum: nil,
            hashTags: ["필터", "사진"]
        )
        return UserClient(
            myInfo: { mockInfo },
            editMyProfile: { query in
                MyInfoResponseDTO(
                    userID: mockInfo.userID,
                    email: mockInfo.email,
                    nick: query.nick ?? mockInfo.nick,
                    name: query.name,
                    introduction: query.introduction,
                    profileImage: query.profileImage,
                    phoneNum: query.phoneNum,
                    hashTags: query.hashTags ?? mockInfo.hashTags
                )
            },
            uploadProfileImage: { _ in "/profile/test.jpg" },
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
