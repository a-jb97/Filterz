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
    let format: String?
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

    var dateTimeOriginalFormatted: String? {
        guard let dateTimeOriginal else { return nil }
        return formatPhotoMetadataDate(dateTimeOriginal)
    }
}

private nonisolated func formatPhotoMetadataDate(_ dateString: String) -> String {
    let isoWithFraction = ISO8601DateFormatter()
    isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let isoWithoutFraction = ISO8601DateFormatter()
    isoWithoutFraction.formatOptions = [.withInternetDateTime]

    let date = isoWithFraction.date(from: dateString)
        ?? isoWithoutFraction.date(from: dateString)
        ?? parsePhotoMetadataDate(dateString)

    guard let date else { return dateString }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy. MM. dd. a hh:mm"
    formatter.timeZone = .current
    return formatter.string(from: date)
}

private nonisolated func parsePhotoMetadataDate(_ dateString: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.timeZone = .current

    for format in [
        "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
        "yyyy-MM-dd'T'HH:mm:ssXXXXX",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy:MM:dd HH:mm:ss"
    ] {
        formatter.dateFormat = format
        if let date = formatter.date(from: dateString) {
            return date
        }
    }

    return nil
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
        format = dto.format
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
    var isDownloaded: Bool
    var likeCount: Int
    var buyerCount: Int
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

struct PortOnePaymentRequest: Equatable, Sendable, Identifiable {
    let id: String
    let userCode: String
    let merchantUid: String
    let amount: String
    let payMethod: String
    let name: String
    let buyerName: String
    let appScheme: String
}

struct PortOnePaymentResult: Equatable, Sendable {
    let success: Bool
    let impUid: String?
    let merchantUid: String?
    let errorMessage: String?
}

extension FilterDetail {
    init(dto: FilterResponseDTO, currentUserId: String = "") {
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
        isDownloaded = dto.isDownloaded || dto.creator.userID == currentUserId
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
        var currentUserId: String = KeychainHelper.load(forKey: "userId") ?? ""
        var detail: FilterDetail? = nil
        var isLoading: Bool = false
        var isLikeInProgress: Bool = false
        var previewSliderOffset: CGFloat = 0.5
        var isPurchaseLoading: Bool = false
        var isDeleteLoading: Bool = false
        var paymentRequest: PortOnePaymentRequest? = nil
        var errorMessage: String? = nil
        @Presents var alert: AlertState<Action.Alert>?
    }

    enum Action: Sendable {
        case onAppear
        case detailResponse(Result<FilterResponseDTO, any Error>)
        case backTapped
        case likeTapped
        case likeResponse(Result<Void, any Error>)
        case previewSliderChanged(CGFloat)
        case purchaseTapped
        case createOrderResponse(Result<OrderCreateResponseDTO, any Error>)
        case portOnePaymentFinished(PortOnePaymentResult)
        case paymentValidationResponse(Result<PaymentResponseDTO, any Error>)
        case paymentSheetDismissed
        case creatorProfileTapped
        case dmCreatorTapped
        case editTapped
        case deleteTapped
        case deleteResponse(Result<Void, any Error>)
        case editCompleted(FilterResponseDTO)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        enum Alert: Equatable {
            case confirmDelete
        }

        @CasePathable
        enum Delegate: Sendable {
            case backTapped
            case userProfileTapped(userId: String)
            case dmCreatorTapped(creatorId: String)
            case editFilterRequested(FilterDetail)
            case filterDeleted
        }
    }

    @Dependency(\.filterClient) var filterClient
    @Dependency(\.paymentClient) var paymentClient

    private func makeAlert(title: String, message: String?) -> AlertState<Action.Alert> {
        AlertState {
            TextState(title)
        } actions: {
            ButtonState(role: .cancel) { TextState("확인") }
        } message: {
            TextState(message ?? "오류가 발생했습니다.")
        }
    }

    private func makeDeleteConfirmationAlert(title: String) -> AlertState<Action.Alert> {
        AlertState {
            TextState("필터 삭제")
        } actions: {
            ButtonState(role: .destructive, action: .confirmDelete) {
                TextState("삭제")
            }
            ButtonState(role: .cancel) {
                TextState("취소")
            }
        } message: {
            TextState("'\(title)' 필터를 삭제하시겠습니까? 삭제한 필터는 복구할 수 없습니다.")
        }
    }

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
                state.detail = FilterDetail(dto: dto, currentUserId: state.currentUserId)
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
                guard let detail = state.detail,
                      !detail.isDownloaded,
                      detail.creator.id != state.currentUserId,
                      !state.isPurchaseLoading
                else { return .none }
                state.isPurchaseLoading = true
                return .run { [filterId = detail.id, totalPrice = detail.price] send in
                    await send(.createOrderResponse(
                        Result { try await paymentClient.createOrder(filterId, totalPrice) }
                    ))
                }

            case .createOrderResponse(.success(let order)):
                guard let detail = state.detail else {
                    state.isPurchaseLoading = false
                    return .none
                }
                guard order.totalPrice == detail.price else {
                    state.isPurchaseLoading = false
                    state.alert = makeAlert(title: "결제 오류", message: "주문 금액과 필터 금액이 일치하지 않습니다.")
                    return .none
                }
                state.paymentRequest = PortOnePaymentRequest(
                    id: order.orderCode,
                    userCode: "imp14511373",
                    merchantUid: order.orderCode,
                    amount: "\(order.totalPrice)",
                    payMethod: "card",
                    name: detail.title,
                    buyerName: "전민석",
                    appScheme: "Filterz"
                )
                return .none

            case .createOrderResponse(.failure(let error)):
                state.isPurchaseLoading = false
                state.alert = makeAlert(title: "주문 생성 실패", message: error.localizedDescription)
                return .none

            case .portOnePaymentFinished(let result):
                state.paymentRequest = nil
                guard result.success else {
                    state.isPurchaseLoading = false
                    state.alert = makeAlert(title: "결제 실패", message: result.errorMessage ?? "결제가 취소되었거나 승인되지 않았습니다.")
                    return .none
                }
                guard let impUid = result.impUid, !impUid.isEmpty else {
                    state.isPurchaseLoading = false
                    state.alert = makeAlert(title: "결제 검증 실패", message: "결제 번호를 확인할 수 없습니다.")
                    return .none
                }
                return .run { send in
                    await send(.paymentValidationResponse(
                        Result { try await paymentClient.validatePayment(impUid) }
                    ))
                }

            case .paymentValidationResponse(.success):
                state.isPurchaseLoading = false
                if state.detail?.isDownloaded == false {
                    state.detail?.buyerCount += 1
                }
                state.detail?.isDownloaded = true
                state.alert = makeAlert(title: "결제 완료", message: "필터 구매가 완료되었습니다.")
                return .none

            case .paymentValidationResponse(.failure(let error)):
                state.isPurchaseLoading = false
                state.alert = makeAlert(title: "결제 검증 실패", message: error.localizedDescription)
                return .none

            case .paymentSheetDismissed:
                let wasPresentingPayment = state.paymentRequest != nil
                state.paymentRequest = nil
                if wasPresentingPayment, state.isPurchaseLoading {
                    state.isPurchaseLoading = false
                    state.alert = makeAlert(title: "결제 취소", message: "결제가 완료되지 않았습니다.")
                }
                return .none

            case .creatorProfileTapped:
                guard let creatorId = state.detail?.creator.id else { return .none }
                return .send(.delegate(.userProfileTapped(userId: creatorId)))

            case .dmCreatorTapped:
                guard let creatorId = state.detail?.creator.id,
                      creatorId != state.currentUserId else { return .none }
                return .send(.delegate(.dmCreatorTapped(creatorId: creatorId)))

            case .editTapped:
                guard let detail = state.detail,
                      detail.creator.id == state.currentUserId else { return .none }
                return .send(.delegate(.editFilterRequested(detail)))

            case .deleteTapped:
                guard let detail = state.detail,
                      detail.creator.id == state.currentUserId,
                      !state.isDeleteLoading else { return .none }
                state.alert = makeDeleteConfirmationAlert(title: detail.title)
                return .none

            case .alert(.presented(.confirmDelete)):
                guard let detail = state.detail,
                      detail.creator.id == state.currentUserId,
                      !state.isDeleteLoading else { return .none }
                state.isDeleteLoading = true
                return .run { [filterId = detail.id] send in
                    await send(.deleteResponse(
                        Result { try await filterClient.deleteFilter(filterId) }
                    ))
                }

            case .deleteResponse(.success):
                state.isDeleteLoading = false
                return .send(.delegate(.filterDeleted))

            case .deleteResponse(.failure(let error)):
                state.isDeleteLoading = false
                state.alert = makeAlert(title: "삭제 실패", message: error.localizedDescription)
                return .none

            case .editCompleted(let dto):
                state.detail = FilterDetail(dto: dto, currentUserId: state.currentUserId)
                return .none

            case .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
