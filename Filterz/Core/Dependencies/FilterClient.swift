import ComposableArchitecture
import Foundation

struct FilterClient: Sendable {
    var getTodayFilter: @Sendable () async throws -> TodayFilterResponseDTO
    var getHotTrendFilters: @Sendable () async throws -> FilterSummaryListResponseDTO
    var getFilters: @Sendable (_ next: String?, _ category: String?) async throws -> FilterSummaryPaginationListResponseDTO
    var getFilterDetail: @Sendable (_ id: String) async throws -> FilterResponseDTO
    var likeFilter: @Sendable (_ id: String, _ status: Bool) async throws -> Void
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
            getFilters: { next, category in
                try await NetworkManager.shared.request(.getFilters(next: next, category: category))
            },
            getFilterDetail: { id in
                try await NetworkManager.shared.request(.getFilter(id: id))
            },
            likeFilter: { id, status in
                try await NetworkManager.shared.requestVoid(.likeFilter(id: id, query: FilterLikeRequestDTO(likeStatus: status)))
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
        let mockDetailCreator = UserInfoResponseDTO(userID: "u1", nick: "윤새싹", profileImage: nil)
        let mockDetail = FilterResponseDTO(
            filterId: "mock-id",
            category: "moody",
            title: "청록새록",
            description: "햇살 아래 돋아나는 새싹처럼,\n맑고 투명한 빛을 담은 자연 감성 필터입니다.\n너무 과하지 않게, 부드러운 색감으로 분위기를 살려줍니다.",
            files: [],
            price: 2000,
            creator: mockDetailCreator,
            photoMetadata: PhotoMetadataDTO(
                camera: "Apple iPhone 16 Pro",
                lensInfo: "와이드 카메라 - 26mm",
                focalLength: 26,
                aperture: 1.5,
                iso: 400,
                shutterSpeed: "1/120",
                pixelWidth: 3024,
                pixelHeight: 4032,
                fileSize: 2.2,
                format: "JPEG",
                dateTimeOriginal: "서울 영등포구 선유로 9일 30",
                latitude: 37.5266,
                longitude: 126.9024
            ),
            filterValues: FilterValuesDTO(
                brightness: -3.5,
                exposure: 1.5,
                contrast: 2.5,
                saturation: 0.1,
                sharpness: -4.0,
                blur: 10.5,
                vignette: -6.0,
                noiseReduction: 7.5,
                highlights: 0.5,
                shadows: 0.5,
                temperature: -1.0,
                blackPoint: 5.5
            ),
            isLiked: false,
            isDownloaded: false,
            likeCount: 800,
            buyerCount: 2400,
            comments: [],
            createdAt: "2025-09-01T00:00:00",
            updatedAt: "2025-09-01T00:00:00"
        )
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
            getFilters: { _, _ in FilterSummaryPaginationListResponseDTO(data: mockFilters.data, nextCursor: nil) },
            getFilterDetail: { _ in mockDetail },
            likeFilter: { _, _ in }
        )
    }
}

extension DependencyValues {
    var filterClient: FilterClient {
        get { self[FilterClient.self] }
        set { self[FilterClient.self] = newValue }
    }
}
