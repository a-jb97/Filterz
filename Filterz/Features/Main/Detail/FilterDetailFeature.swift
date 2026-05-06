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
        return String(format: "%.1fMB", size / 1_048_576)
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

extension FilterExifData {
    static let empty = FilterExifData(
        camera: nil,
        lensInfo: nil,
        focalLength: nil,
        aperture: nil,
        iso: nil,
        shutterSpeed: nil,
        pixelWidth: nil,
        pixelHeight: nil,
        fileSize: nil,
        format: nil,
        dateTimeOriginal: nil,
        latitude: nil,
        longitude: nil
    )
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
    nonisolated init(dto: PhotoMetadataDTO) {
        camera = dto.camera
        lensInfo = dto.lensInfo
        focalLength = dto.focalLength.map(Float.init)
        aperture = dto.aperture.map(Float.init)
        iso = dto.iso
        shutterSpeed = dto.shutterSpeed
        pixelWidth = dto.pixelWidth
        pixelHeight = dto.pixelHeight
        fileSize = dto.fileSize
        format = dto.format
        dateTimeOriginal = dto.dateTimeOriginal
        latitude = dto.latitude.map(Float.init)
        longitude = dto.longitude.map(Float.init)
    }
}

struct FilterPresetValues: Equatable, Sendable {
    static let empty = FilterPresetValues(
        brightness: nil,
        exposure: nil,
        contrast: nil,
        saturation: nil,
        sharpness: nil,
        blur: nil,
        vignette: nil,
        noiseReduction: nil,
        highlights: nil,
        shadows: nil,
        temperature: nil,
        blackPoint: nil
    )

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
    nonisolated init(dto: FilterValuesDTO) {
        brightness = dto.brightness.map(Float.init)
        exposure = dto.exposure.map(Float.init)
        contrast = dto.contrast.map(Float.init)
        saturation = dto.saturation.map(Float.init)
        sharpness = dto.sharpness.map(Float.init)
        blur = dto.blur.map(Float.init)
        vignette = dto.vignette.map(Float.init)
        noiseReduction = dto.noiseReduction.map(Float.init)
        highlights = dto.highlights.map(Float.init)
        shadows = dto.shadows.map(Float.init)
        temperature = dto.temperature.map(Float.init)
        blackPoint = dto.blackPoint.map(Float.init)
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
    var comments: [FilterComment]
    let createdAt: String

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let numStr = formatter.string(from: NSNumber(value: price)) ?? "\(price)"
        return "\(numStr) KRW"
    }

    var hashtags: [String] {
        [category]
    }
}

struct FilterComment: Equatable, Sendable, Identifiable {
    let id: String
    let content: String
    let createdAt: String
    let creator: FilterCreator
    let replies: [FilterComment]

    var createdAtFormatted: String {
        formatPhotoMetadataDate(createdAt)
    }
}

extension FilterComment {
    nonisolated init(dto: FilterCommentResponseDTO) {
        id = dto.commentId
        content = dto.content
        createdAt = dto.createdAt
        creator = FilterCreator(
            id: dto.creator.userID,
            nick: dto.creator.nick,
            profileImagePath: dto.creator.profileImage
        )
        replies = dto.replies.map { FilterComment(dto: $0) }
    }

    nonisolated init(dto: CommentResponseDTO) {
        id = dto.commentId
        content = dto.content
        createdAt = dto.createdAt
        creator = FilterCreator(
            id: dto.creator.userID,
            nick: dto.creator.nick,
            profileImagePath: dto.creator.profileImage
        )
        replies = []
    }
}

struct FilterCommentTarget: Equatable, Sendable, Identifiable {
    let id: String
    let parentId: String?
    let content: String
    let creator: FilterCreator

    var isReply: Bool {
        parentId != nil
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
        exif = dto.photoMetadata.map(FilterExifData.init(dto:)) ?? .empty
        presets = dto.filterValues.map(FilterPresetValues.init(dto:)) ?? .empty
        isLiked = dto.isLiked
        isDownloaded = dto.isDownloaded || dto.creator.userID == currentUserId
        likeCount = dto.likeCount
        buyerCount = dto.buyerCount
        comments = dto.comments.map(FilterComment.init(dto:))
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
        var commentText: String = ""
        var replyTarget: FilterCommentTarget? = nil
        var editingComment: FilterCommentTarget? = nil
        var deletingComment: FilterCommentTarget? = nil
        var isCommentSubmitting: Bool = false
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
        case commentTextChanged(String)
        case replyTapped(commentId: String)
        case editCommentTapped(commentId: String)
        case deleteCommentTapped(commentId: String)
        case cancelCommentModeTapped
        case submitCommentTapped
        case createCommentResponse(Result<Void, any Error>)
        case editCommentResponse(Result<Void, any Error>)
        case deleteCommentResponse(Result<Void, any Error>)
        case commentsRefreshResponse(Result<FilterResponseDTO, any Error>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        enum Alert: Equatable {
            case confirmDelete
            case confirmDeleteComment
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

    private func makeCommentDeleteConfirmationAlert(isReply: Bool) -> AlertState<Action.Alert> {
        AlertState {
            TextState(isReply ? "대댓글 삭제" : "댓글 삭제")
        } actions: {
            ButtonState(role: .destructive, action: .confirmDeleteComment) {
                TextState("삭제")
            }
            ButtonState(role: .cancel) {
                TextState("취소")
            }
        } message: {
            TextState(isReply ? "대댓글을 삭제하시겠습니까?" : "댓글을 삭제하시겠습니까? 댓글에 달린 대댓글도 함께 삭제됩니다.")
        }
    }

    private func findCommentTarget(in comments: [FilterComment], commentId: String) -> FilterCommentTarget? {
        for comment in comments {
            if comment.id == commentId {
                return FilterCommentTarget(
                    id: comment.id,
                    parentId: nil,
                    content: comment.content,
                    creator: comment.creator
                )
            }

            if let reply = comment.replies.first(where: { $0.id == commentId }) {
                return FilterCommentTarget(
                    id: reply.id,
                    parentId: comment.id,
                    content: reply.content,
                    creator: reply.creator
                )
            }
        }

        return nil
    }

    private func refreshDetailEffect(filterId: String) -> Effect<Action> {
        .run { send in
            await send(.commentsRefreshResponse(
                Result { try await filterClient.getFilterDetail(filterId) }
            ))
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
                state.previewSliderOffset = 0.5
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

            case .commentTextChanged(let text):
                state.commentText = text
                return .none

            case .replyTapped(let commentId):
                guard let detail = state.detail,
                      let target = findCommentTarget(in: detail.comments, commentId: commentId),
                      !target.isReply
                else { return .none }
                state.replyTarget = target
                state.editingComment = nil
                state.commentText = ""
                return .none

            case .editCommentTapped(let commentId):
                guard let detail = state.detail,
                      let target = findCommentTarget(in: detail.comments, commentId: commentId),
                      target.creator.id == state.currentUserId
                else { return .none }
                state.editingComment = target
                state.replyTarget = nil
                state.commentText = target.content
                return .none

            case .deleteCommentTapped(let commentId):
                guard let detail = state.detail,
                      let target = findCommentTarget(in: detail.comments, commentId: commentId),
                      target.creator.id == state.currentUserId,
                      !state.isCommentSubmitting
                else { return .none }
                state.deletingComment = target
                state.alert = makeCommentDeleteConfirmationAlert(isReply: target.isReply)
                return .none

            case .cancelCommentModeTapped:
                state.replyTarget = nil
                state.editingComment = nil
                state.commentText = ""
                return .none

            case .submitCommentTapped:
                guard let detail = state.detail,
                      !state.isCommentSubmitting
                else { return .none }
                let content = state.commentText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !content.isEmpty else { return .none }
                state.isCommentSubmitting = true

                if let editingComment = state.editingComment {
                    guard editingComment.creator.id == state.currentUserId else {
                        state.isCommentSubmitting = false
                        return .none
                    }
                    let query = FilterCommentRequestDTO(content: content, parentComment: nil)
                    return .run { [filterId = detail.id, commentId = editingComment.id] send in
                        await send(.editCommentResponse(
                            Result { try await filterClient.editFilterComment(filterId, commentId, query) }
                        ))
                    }
                }

                let query = FilterCommentRequestDTO(
                    content: content,
                    parentComment: state.replyTarget?.id
                )
                return .run { [filterId = detail.id] send in
                    await send(.createCommentResponse(
                        Result { try await filterClient.createFilterComment(filterId, query) }
                    ))
                }

            case .createCommentResponse(.success):
                state.isCommentSubmitting = false
                state.commentText = ""
                state.replyTarget = nil
                return refreshDetailEffect(filterId: state.filterId)

            case .createCommentResponse(.failure(let error)):
                state.isCommentSubmitting = false
                state.alert = makeAlert(title: "댓글 작성 실패", message: error.localizedDescription)
                return .none

            case .editCommentResponse(.success):
                state.isCommentSubmitting = false
                state.commentText = ""
                state.editingComment = nil
                return refreshDetailEffect(filterId: state.filterId)

            case .editCommentResponse(.failure(let error)):
                state.isCommentSubmitting = false
                state.alert = makeAlert(title: "댓글 수정 실패", message: error.localizedDescription)
                return .none

            case .alert(.presented(.confirmDeleteComment)):
                guard let target = state.deletingComment,
                      target.creator.id == state.currentUserId,
                      !state.isCommentSubmitting
                else { return .none }
                state.isCommentSubmitting = true
                return .run { [filterId = state.filterId, commentId = target.id] send in
                    await send(.deleteCommentResponse(
                        Result { try await filterClient.deleteFilterComment(filterId, commentId) }
                    ))
                }

            case .deleteCommentResponse(.success):
                state.isCommentSubmitting = false
                state.deletingComment = nil
                return refreshDetailEffect(filterId: state.filterId)

            case .deleteCommentResponse(.failure(let error)):
                state.isCommentSubmitting = false
                state.deletingComment = nil
                state.alert = makeAlert(title: "댓글 삭제 실패", message: error.localizedDescription)
                return .none

            case .commentsRefreshResponse(.success(let dto)):
                state.detail = FilterDetail(dto: dto, currentUserId: state.currentUserId)
                return .none

            case .commentsRefreshResponse(.failure(let error)):
                state.alert = makeAlert(title: "댓글 새로고침 실패", message: error.localizedDescription)
                return .none

            case .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
