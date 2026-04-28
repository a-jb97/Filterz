import ComposableArchitecture
import Foundation

struct FilterClient: Sendable {
    var getTodayFilter: @Sendable () async throws -> TodayFilterResponseDTO
    var getHotTrendFilters: @Sendable () async throws -> FilterSummaryListResponseDTO
    var getFilters: @Sendable () async throws -> FilterSummaryListResponseDTO
}

extension FilterClient: DependencyKey {
    static var liveValue: FilterClient {
        FilterClient(
            getTodayFilter: {
                try await NetworkManager.shared.request(.getTodayFilter)
            },
            getHotTrendFilters: {
                try await NetworkManager.shared.request(.getHotTrendFilters)
            },
            getFilters: {
                try await NetworkManager.shared.request(.getFilters)
            }
        )
    }

    static var testValue: FilterClient {
        let mockCreator = UserInfoResponseDTO(userID: "u1", nick: "tester", profileImage: nil)
        let mockFilters = FilterSummaryListResponseDTO(data: [
            FilterSummaryResponseDTO(filterId: "1", category: "moody", title: "강철", description: "", files: [], creator: mockCreator, isLiked: false, likeCount: 30, buyerCount: 0, createdAt: "", updatedAt: ""),
            FilterSummaryResponseDTO(filterId: "2", category: "moody", title: "소낙새", description: "", files: [], creator: mockCreator, isLiked: false, likeCount: 121, buyerCount: 0, createdAt: "", updatedAt: ""),
            FilterSummaryResponseDTO(filterId: "3", category: "moody", title: "화양연화", description: "", files: [], creator: mockCreator, isLiked: false, likeCount: 226, buyerCount: 0, createdAt: "", updatedAt: "")
        ])
        return FilterClient(
            getTodayFilter: {
                TodayFilterResponseDTO(
                    filterId: "test-id",
                    title: "테스트 필터",
                    introduction: "테스트 소개",
                    description: "테스트 설명",
                    files: [],
                    createdAt: "",
                    updatedAt: ""
                )
            },
            getHotTrendFilters: { mockFilters },
            getFilters: { mockFilters }
        )
    }
}

extension DependencyValues {
    var filterClient: FilterClient {
        get { self[FilterClient.self] }
        set { self[FilterClient.self] = newValue }
    }
}
