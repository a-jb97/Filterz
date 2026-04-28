import ComposableArchitecture
import Foundation

// MARK: - Domain Models

struct FilterCreator: Equatable, Sendable {
    let id: String
    let nick: String
    let profileImagePath: String?
}

struct FilterExifData: Equatable, Sendable {
    let camera: String?
    let lensInfo: String?
    let focalLength: Float?
    let aperture: Float?
    let iso: Int?
    let shutterSpeed: String?
    let pixelWidth: Int?
    let pixelHeight: Int?
    let fileSize: Double?
    let dateTimeOriginal: String?
    let latitude: Float?
    let longitude: Float?

    var megapixels: String? {
        guard let w = pixelWidth, let h = pixelHeight else { return nil }
        let mp = Double(w) * Double(h) / 1_000_000
        return String(format: "%.0fMP", mp)
    }

    var fileSizeFormatted: String? {
        guard let size = fileSize else { return nil }
        return String(format: "%.1fMB", size)
    }

    var dimensionsFormatted: String? {
        guard let w = pixelWidth, let h = pixelHeight else { return nil }
        return "\(w) × \(h)"
    }
}

extension FilterExifData {
    init(dto: PhotoMetadataDTO) {
        camera = dto.camera
        lensInfo = dto.lensInfo
        focalLength = dto.focalLength
        aperture = dto.aperture
        iso = dto.iso
        shutterSpeed = dto.shutterSpeed
        pixelWidth = dto.pixelWidth
        pixelHeight = dto.pixelHeight
        fileSize = dto.fileSize
        dateTimeOriginal = dto.dateTimeOriginal
        latitude = dto.latitude
        longitude = dto.longitude
    }
}

struct FilterPresetValues: Equatable, Sendable {
    let brightness: Float?
    let exposure: Float?
    let contrast: Float?
    let saturation: Float?
    let sharpness: Float?
    let blur: Float?
    let vignette: Float?
    let noiseReduction: Float?
    let highlights: Float?
    let shadows: Float?
    let temperature: Float?
    let blackPoint: Float?

    var displayParams: [(name: String, value: Float)] {
        let all: [(String, Float?)] = [
            ("Brightness", brightness),
            ("Exposure", exposure),
            ("Contrast", contrast),
            ("Saturation", saturation),
            ("Sharpness", sharpness),
            ("Blur", blur),
            ("Vignette", vignette),
            ("NR", noiseReduction),
            ("Highlights", highlights),
            ("Shadows", shadows),
            ("Temperature", temperature),
            ("BlackPoint", blackPoint)
        ]
        return all.compactMap { name, val in val.map { (name, $0) } }
    }
}

extension FilterPresetValues {
    init(dto: FilterValuesDTO) {
        brightness = dto.brightness
        exposure = dto.exposure
        contrast = dto.contrast
        saturation = dto.saturation
        sharpness = dto.sharpness
        blur = dto.blur
        vignette = dto.vignette
        noiseReduction = dto.noiseReduction
        highlights = dto.highlights
        shadows = dto.shadows
        temperature = dto.temperature
        blackPoint = dto.blackPoint
    }
}

struct FilterDetail: Equatable, Sendable, Identifiable {
    let id: String
    let category: String
    let title: String
    let description: String
    let imageURLs: [String]
    let price: Int
    let creator: FilterCreator
    let exif: FilterExifData
    let presets: FilterPresetValues
    var isLiked: Bool
    let isDownloaded: Bool
    var likeCount: Int
    let buyerCount: Int
    let createdAt: String

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let numStr = formatter.string(from: NSNumber(value: price)) ?? "\(price)"
        return "\(numStr) Coin"
    }

    var hashtags: [String] {
        [category]
    }
}

extension FilterDetail {
    init(dto: FilterResponseDTO) {
        id = dto.filterId
        category = dto.category
        title = dto.title
        description = dto.description
        imageURLs = dto.files
        price = dto.price
        creator = FilterCreator(
            id: dto.creator.userID,
            nick: dto.creator.nick,
            profileImagePath: dto.creator.profileImage
        )
        exif = FilterExifData(dto: dto.photoMetadata)
        presets = FilterPresetValues(dto: dto.filterValues)
        isLiked = dto.isLiked
        isDownloaded = dto.isDownloaded
        likeCount = dto.likeCount
        buyerCount = dto.buyerCount
        createdAt = dto.createdAt
    }
}

// MARK: - FilterDetailFeature

@Reducer
struct FilterDetailFeature {

    @ObservableState
    struct State: Equatable {
        let filterId: String
        var detail: FilterDetail? = nil
        var isLoading: Bool = false
        var isLikeInProgress: Bool = false
        var previewSliderOffset: CGFloat = 0.5
        var isPurchaseLoading: Bool = false
        var errorMessage: String? = nil
    }

    enum Action: Sendable {
        case onAppear
        case detailResponse(Result<FilterResponseDTO, any Error>)
        case backTapped
        case likeTapped
        case likeResponse(Result<Void, any Error>)
        case previewSliderChanged(CGFloat)
        case purchaseTapped
        case dmCreatorTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case backTapped
            case dmCreatorTapped(creatorId: String)
        }
    }

    @Dependency(\.filterClient) var filterClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.detail == nil, !state.isLoading else { return .none }
                state.isLoading = true
                let id = state.filterId
                return .run { send in
                    await send(.detailResponse(
                        Result { try await filterClient.getFilterDetail(id) }
                    ))
                }

            case .detailResponse(.success(let dto)):
                state.isLoading = false
                state.detail = FilterDetail(dto: dto)
                return .none

            case .detailResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case .backTapped:
                return .send(.delegate(.backTapped))

            case .likeTapped:
                guard let detail = state.detail, !state.isLikeInProgress else { return .none }
                let wasLiked = detail.isLiked
                state.isLikeInProgress = true
                state.detail?.isLiked = !wasLiked
                state.detail?.likeCount += wasLiked ? -1 : 1
                let id = state.filterId
                let targetStatus = !wasLiked
                return .run { send in
                    do {
                        try await filterClient.likeFilter(id, targetStatus)
                        await send(.likeResponse(.success(())))
                    } catch {
                        print("❌ likeFilter failed: \(error)")
                        await send(.likeResponse(.failure(error)))
                    }
                }

            case .likeResponse(.success):
                state.isLikeInProgress = false
                return .none

            case .likeResponse(.failure(let error)):
                print("❌ likeResponse failure received: \(error)")
                state.isLikeInProgress = false
                guard let detail = state.detail else { return .none }
                state.detail?.isLiked = !detail.isLiked
                state.detail?.likeCount += detail.isLiked ? -1 : 1
                return .none

            case .previewSliderChanged(let offset):
                state.previewSliderOffset = max(0, min(1, offset))
                return .none

            case .purchaseTapped:
                state.isPurchaseLoading = true
                return .none

            case .dmCreatorTapped:
                guard let creatorId = state.detail?.creator.id else { return .none }
                return .send(.delegate(.dmCreatorTapped(creatorId: creatorId)))

            case .delegate:
                return .none
            }
        }
    }
}
