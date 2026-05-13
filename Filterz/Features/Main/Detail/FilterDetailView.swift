import SwiftUI
import ComposableArchitecture
import PhotosUI
import UIKit
import WebKit
import iamport_ios
import Then

struct FilterDetailView: View {
    @Bindable var store: StoreOf<FilterDetailFeature>
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            detailNavBar

            ZStack {
                Color.filterzBlackBase.ignoresSafeArea()

                if store.isLoading {
                    ProgressView()
                        .tint(.filterzGray45)
                } else if let detail = store.detail {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            previewSection(detail: detail)
                            priceSection(detail: detail)
                            statsSection(detail: detail)
                            EXIFSection(
                                exif: detail.exif,
                                onMapTapped: { store.send(.exifMapTapped($0)) }
                            )
                                .padding(.horizontal, 16)
                            FilterPresetsSection(presets: detail.presets, isUnlocked: detail.isDownloaded)
                                .padding(.horizontal, 16)
                            purchaseButton(detail: detail)
                                .padding(.horizontal, 16)
                            CreatorSection(
                                creator: detail.creator,
                                accessory: creatorAccessory(detail: detail),
                                onProfileTapped: { store.send(.creatorProfileTapped) },
                                onDMTapped: { store.send(.dmCreatorTapped) },
                                onEditTapped: { store.send(.editTapped) },
                                onDeleteTapped: { store.send(.deleteTapped) }
                            )
                            .padding(.horizontal, 16)
                            hashtagsSection(detail: detail)
                            descriptionSection(detail: detail)
                            commentsSection(detail: detail)
                                .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 40)
                        .padding(.top, 8)
                    }
                } else if let error = store.errorMessage {
                    Text(error)
                        .font(.pretendard(14, weight: .regular))
                        .foregroundColor(.filterzGray60)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay {
            if store.isFilterRendering {
                ZStack {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()

                    ProgressView()
                        .tint(.filterzAccent)
                        .scaleEffect(1.1)
                }
            }
        }
        .background(Color.filterzBlackBase.ignoresSafeArea())
        .filterzSwipeBack {
            store.send(.backTapped)
        }
        .onAppear { store.send(.onAppear) }
        .photosPicker(
            isPresented: Binding(
                get: { store.isPhotoPickerPresented },
                set: { isPresented in
                    if !isPresented {
                        store.send(.photoPickerDismissed)
                    }
                }
            ),
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    await MainActor.run {
                        selectedPhotoItem = nil
                        store.send(.photoPickerDismissed)
                    }
                    return
                }
                await MainActor.run {
                    selectedPhotoItem = nil
                    store.send(.photoSelected(data))
                }
            }
        }
        .fullScreenCover(
            item: Binding(
                get: { store.paymentRequest },
                set: { newValue in
                    if newValue == nil {
                        store.send(.paymentSheetDismissed)
                    }
                }
            )
        ) { request in
            PortOnePaymentView(request: request) { result in
                store.send(.portOnePaymentFinished(result))
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { store.appliedPreviewImageData != nil },
                set: { isPresented in
                    if !isPresented {
                        store.send(.applyPreviewDismissed)
                    }
                }
            )
        ) {
            if let imageData = store.appliedPreviewImageData {
                AppliedFilterPreviewView(
                    imageData: imageData,
                    isSaving: store.isAppliedPhotoSaving,
                    onApply: { store.send(.saveAppliedPhotoTapped) },
                    onDismiss: { store.send(.applyPreviewDismissed) }
                )
            }
        }
        .sheet(
            item: Binding(
                get: { store.exifMapLocation },
                set: { newValue in
                    if newValue == nil {
                        store.send(.exifMapDismissed)
                    }
                }
            )
        ) { location in
            EXIFMapSheetView(location: location)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // MARK: - Navigation Bar

    private var detailNavBar: some View {
        HStack {
            Button { store.send(.backTapped) } label: {
                Image(systemName: "chevron.left")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10, height: 18)
                    .foregroundColor(.filterzGray60)
                    .padding(8)
            }
            .frame(width: 48, height: 48)

            Spacer()

            Text(store.detail?.title ?? "")
                .font(.filterzDisplay(18))
                .foregroundColor(.filterzGray30)
                .lineLimit(1)

            Spacer()

            Button { store.send(.likeTapped) } label: {
                Image(systemName: store.detail?.isLiked == true ? "heart.fill" : "heart")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 20)
                    .foregroundColor(store.detail?.isLiked == true ? .red : .filterzGray60)
                    .scaleEffect(store.detail?.isLiked == true ? 1.15 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: store.detail?.isLiked)
                    .padding(8)
            }
            .frame(width: 48, height: 48)
        }
        .padding(.horizontal, 4)
        .frame(height: 56)
        .background(Color.filterzBlackBase)
    }

    // MARK: - Sections

    private func previewSection(detail: FilterDetail) -> some View {
        FilterPreviewView(
            afterImageURL: detail.imageURLs.first,
            beforeImageURL: detail.imageURLs.dropFirst().first,
            values: FilterAdjustmentValues(presets: detail.presets),
            sliderOffset: store.previewSliderOffset,
            onSliderChanged: { store.send(.previewSliderChanged($0)) }
        )
        .padding(.horizontal, 16)
    }

    private func creatorAccessory(detail: FilterDetail) -> CreatorSection.Accessory {
        if detail.creator.id == store.currentUserId {
            return .ownerActions
        }
        return detail.creator.id.isEmpty ? .none : .dm
    }

    private func priceSection(detail: FilterDetail) -> some View {
        Text(detail.formattedPrice)
            .font(.filterzDisplay(32))
            .foregroundColor(.filterzGray30)
            .padding(.horizontal, 16)
    }

    private func statsSection(detail: FilterDetail) -> some View {
        HStack(spacing: 12) {
            statCard(title: "다운로드", value: "\(detail.buyerCount)+")
            statCard(title: "찜하기", value: "\(detail.likeCount)")
        }
        .padding(.horizontal, 16)
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.pretendard(12, weight: .medium))
                .foregroundColor(.filterzGray75)
            Text(value)
                .font(.filterzDisplay(24))
                .foregroundColor(.filterzGray30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.filterzBlackAccent)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.filterzTranslucent, lineWidth: 1)
                )
        )
    }

    private func purchaseButton(detail: FilterDetail) -> some View {
        let canApplyFilter = detail.isDownloaded || detail.creator.id == store.currentUserId

        return Button {
            if canApplyFilter {
                selectedPhotoItem = nil
                store.send(.applyFilterTapped)
            } else {
                store.send(.purchaseTapped)
            }
        } label: {
            ZStack {
                Text(canApplyFilter ? "적용하기" : "결제하기")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(canApplyFilter ? .filterzTextPrimary : .black)
                    .opacity(store.isPurchaseLoading || store.isFilterRendering ? 0 : 1)

                if store.isPurchaseLoading || store.isFilterRendering {
                    ProgressView()
                        .tint(canApplyFilter ? .filterzTextPrimary : .black)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(canApplyFilter ? Color.filterzDeepSprout : Color.filterzAccent)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(store.isPurchaseLoading || store.isFilterRendering || store.isAppliedPhotoSaving)
    }

    private func hashtagsSection(detail: FilterDetail) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(detail.hashtags, id: \.self) { tag in
                    Text("#\(displayHashTag(tag))")
                        .font(.pretendard(9, weight: .medium))
                        .foregroundColor(.filterzGray30)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(Color.filterzBlackAccent)
                        )
                        .overlay(Capsule().stroke(Color.filterzDeepSprout, lineWidth: 1))
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func descriptionSection(detail: FilterDetail) -> some View {
        Text(detail.description)
            .font(.pretendard(14, weight: .regular))
            .foregroundColor(.filterzGray60)
            .lineSpacing(8)
            .padding(.horizontal, 16)
    }

    private func commentsSection(detail: FilterDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Text("댓글")
                    .font(.pretendard(15, weight: .bold))
                    .foregroundColor(.filterzGray30)

                Text("\(commentCount(detail.comments))")
                    .font(.pretendard(13, weight: .semibold))
                    .foregroundColor(.filterzAccent)
            }

            if detail.comments.isEmpty {
                Text("첫 댓글을 남겨보세요.")
                    .font(.pretendard(13, weight: .regular))
                    .foregroundColor(.filterzGray75)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.filterzBlackAccent)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.filterzTranslucent, lineWidth: 1)
                            )
                    )
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(detail.comments) { comment in
                        commentRow(comment, isReply: false)

                        if !comment.replies.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(comment.replies) { reply in
                                    commentRow(reply, isReply: true)
                                }
                            }
                            .padding(.leading, 24)
                        }
                    }
                }
            }

            commentComposer
        }
    }

    private func commentCount(_ comments: [FilterComment]) -> Int {
        comments.reduce(0) { $0 + 1 + $1.replies.count }
    }

    private func commentRow(_ comment: FilterComment, isReply: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                commentAvatar(comment)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(comment.creator.nick)
                            .font(.pretendard(13, weight: .semibold))
                            .foregroundColor(.filterzGray30)
                            .lineLimit(1)

                        Text(comment.createdAtFormatted)
                            .font(.pretendard(11, weight: .regular))
                            .foregroundColor(.filterzAccent.opacity(0.5))
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }

                    Text(comment.content)
                        .font(.pretendard(13, weight: .regular))
                        .foregroundColor(.filterzGray60)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        if !isReply {
                            commentActionButton("답글") {
                                store.send(.replyTapped(commentId: comment.id))
                            }
                        }

                        if comment.creator.id == store.currentUserId {
                            commentActionButton("수정") {
                                store.send(.editCommentTapped(commentId: comment.id))
                            }
                            commentActionButton("삭제", role: .destructive) {
                                store.send(.deleteCommentTapped(commentId: comment.id))
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isReply ? Color.filterzBlackBase : Color.filterzBlackAccent)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.filterzAccent.opacity(0.5), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func commentAvatar(_ comment: FilterComment) -> some View {
        if comment.creator.id == store.currentUserId {
            avatar(for: comment.creator)
        } else {
            Button {
                store.send(.commentCreatorProfileTapped(commentId: comment.id))
            } label: {
                avatar(for: comment.creator)
            }
            .buttonStyle(.plain)
        }
    }

    private func avatar(for creator: FilterCreator) -> some View {
        ZStack {
            Circle()
                .fill(Color.filterzBlackAccent)

            if let path = creator.profileImagePath, !path.isEmpty {
                AuthenticatedImageView(path: path)
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
            } else {
                Text(String(creator.nick.prefix(1)))
                    .font(.pretendard(12, weight: .bold))
                    .foregroundColor(.filterzGray60)
            }
        }
            .overlay(Circle().stroke(Color.filterzTranslucent, lineWidth: 1))
            .frame(width: 30, height: 30)
    }

    private func commentActionButton(
        _ title: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Text(title)
                .font(.pretendard(12, weight: .medium))
                .foregroundColor(role == .destructive ? .red : .filterzGray75)
        }
        .buttonStyle(.plain)
    }

    private var commentComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let modeText = commentModeText {
                HStack(spacing: 8) {
                    Text(modeText)
                        .font(.pretendard(12, weight: .medium))
                        .foregroundColor(.filterzAccent)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        store.send(.cancelCommentModeTapped)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.filterzGray75)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    commentPlaceholder,
                    text: Binding(
                        get: { store.commentText },
                        set: { store.send(.commentTextChanged($0)) }
                    ),
                    axis: .vertical
                )
                .font(.pretendard(13, weight: .regular))
                .foregroundColor(.filterzGray30)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.filterzBlackAccent)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.filterzTranslucent, lineWidth: 1)
                        )
                )

                Button {
                    store.send(.submitCommentTapped)
                } label: {
                    Group {
                        if store.isCommentSubmitting {
                            ProgressView()
                                .tint(.filterzBlackBase)
                        } else {
                            Image(systemName: store.editingComment == nil ? "paperplane.fill" : "checkmark")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(canSubmitComment ? Color.filterzAccent : Color.filterzBorder))
                    .foregroundColor(.filterzBlackBase)
                }
                .buttonStyle(.plain)
                .disabled(!canSubmitComment || store.isCommentSubmitting)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.filterzBlackBase)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.filterzTranslucent, lineWidth: 1)
                )
        )
    }

    private var commentModeText: String? {
        if store.editingComment != nil {
            return "댓글 수정 중"
        }
        if let replyTarget = store.replyTarget {
            return "@\(replyTarget.creator.nick)에게 답글 작성 중"
        }
        return nil
    }

    private var commentPlaceholder: String {
        store.editingComment == nil ? "댓글을 입력하세요" : "수정할 내용을 입력하세요"
    }

    private var canSubmitComment: Bool {
        !store.commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct PortOnePaymentView: UIViewControllerRepresentable {
    let request: PortOnePaymentRequest
    let onCompletion: (PortOnePaymentResult) -> Void

    func makeUIViewController(context: Context) -> PortOnePaymentViewController {
        let viewController = PortOnePaymentViewController()
        viewController.request = request
        viewController.onCompletion = onCompletion
        return viewController
    }

    func updateUIViewController(_ uiViewController: PortOnePaymentViewController, context: Context) {}
}

private final class PortOnePaymentViewController: UIViewController, WKNavigationDelegate {
    var request: PortOnePaymentRequest?
    var onCompletion: ((PortOnePaymentResult) -> Void)?
    private var didStartPayment = false

    private lazy var wkWebView: WKWebView = {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.navigationDelegate = self
        return webView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 11 / 255, green: 11 / 255, blue: 11 / 255, alpha: 1)
        attachWebView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStartPayment else { return }
        didStartPayment = true
        requestPayment()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        Iamport.shared.close()
        wkWebView.stopLoading()
        wkWebView.navigationDelegate = nil
    }

    private func attachWebView() {
        view.addSubview(wkWebView)
        wkWebView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            wkWebView.topAnchor.constraint(equalTo: view.topAnchor),
            wkWebView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wkWebView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wkWebView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func requestPayment() {
        guard let request else {
            onCompletion?(
                PortOnePaymentResult(
                    success: false,
                    impUid: nil,
                    merchantUid: nil,
                    errorMessage: "결제 요청 정보를 확인할 수 없습니다."
                )
            )
            return
        }

        let payment = IamportPayment(
            pg: PG.html5_inicis.makePgRawName(pgId: "INIpayTest"),
            merchant_uid: request.merchantUid,
            amount: request.amount
        ).then {
            $0.pay_method = request.payMethod
            $0.name = request.name
            $0.buyer_name = request.buyerName
            $0.app_scheme = request.appScheme
        }

        Iamport.shared.paymentWebView(
            webViewMode: wkWebView,
            userCode: request.userCode,
            payment: payment
        ) { [weak self] response in
            self?.onCompletion?(
                PortOnePaymentResult(
                    success: response?.success == true,
                    impUid: response?.imp_uid,
                    merchantUid: response?.merchant_uid,
                    errorMessage: response?.error_msg
                )
            )
        }
    }
}
