import SwiftUI
import ComposableArchitecture
import QuickLook

struct ChatRoomView: View {
    @Bindable var store: StoreOf<ChatRoomFeature>
    @State private var scrollToBottomTrigger = UUID()
    @State private var autoScrollUntil: Date = .distantPast

    var body: some View {
        VStack(spacing: 0) {
            navBar

            messagesList

            if store.showsAISummaryButton || store.isSummarizing {
                aiSummaryButton
            }

            ChatInputBar(
                text: Binding(
                    get: { store.draft },
                    set: { store.send(.draftChanged($0)) }
                ),
                pendingImages: store.pickedImages,
                pendingFiles: store.pickedFiles,
                isSending: store.isSending,
                onSend: { store.send(.sendTapped) },
                onImagesPicked: { store.send(.imagesPicked($0)) },
                onImageRemoved: { store.send(.imageRemoved($0)) },
                onImagePrepared: { store.send(.imagePrepared(id: $0, uploadData: $1, thumbnail: $2)) },
                onFilesPicked: { store.send(.filesPicked($0)) },
                onFileRemoved: { store.send(.fileRemoved($0)) },
                onInvalidAttachment: { store.send(.invalidAttachmentDetected($0)) }
            )
        }
        .background(Color.filterzBlackBase.ignoresSafeArea())
        .filterzSwipeBack {
            store.send(.backTapped)
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { store.imagePreview != nil },
                set: { isPresented in
                    if !isPresented {
                        store.send(.imagePreviewDismissed)
                    }
                }
            )
        ) {
            if let preview = store.imagePreview {
                ChatImagePreviewView(
                    paths: preview.paths,
                    initialIndex: preview.selectedIndex,
                    onDismiss: { store.send(.imagePreviewDismissed) }
                )
            }
        }
        .alert(
            store.errorTitle,
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        store.send(.errorMessageDismissed)
                    }
                }
            )
        ) {
            Button("확인") {
                store.send(.errorMessageDismissed)
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .alert(
            "첨부 불가",
            isPresented: Binding(
                get: { store.attachmentAlert != nil },
                set: { if !$0 { store.send(.attachmentAlertDismissed) } }
            )
        ) {
            Button("확인") { store.send(.attachmentAlertDismissed) }
        } message: {
            Text(store.attachmentAlert ?? "")
        }
        .quickLookPreview(
            Binding(
                get: { store.pdfPreviewURL },
                set: { if $0 == nil { store.send(.pdfPreviewDismissed) } }
            )
        )
        .sheet(
            isPresented: Binding(
                get: { store.isSummarySheetPresented },
                set: { isPresented in
                    if !isPresented {
                        store.send(.summarySheetDismissed)
                    }
                }
            )
        ) {
            summarySheet
                .presentationDetents([.fraction(0.33)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.filterzBlackAccent)
        }
        .onAppear { store.send(.onAppear) }
        .onDisappear { store.send(.onDisappear) }
    }

    private var navBar: some View {
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

            Button {
                store.send(.opponentProfileTapped)
            } label: {
                Text(store.room.opponentNick)
                    .font(.filterzDisplay(18))
                    .foregroundColor(.filterzGray30)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)

            Spacer()

            Color.clear.frame(width: 48, height: 48)
        }
        .padding(.horizontal, 4)
        .frame(height: 56)
        .background(Color.filterzBlackBase)
    }

    private var aiSummaryButton: some View {
        HStack {
            Spacer()

            Button {
                store.send(.aiSummaryButtonTapped)
            } label: {
                HStack(spacing: 7) {
                    if store.isSummarizing {
                        ProgressView()
                            .tint(.filterzAccent)
                            .scaleEffect(0.72)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.filterzAccent)
                    }

                    Text(store.isSummarizing ? "요약 중" : "AI 요약")
                        .font(.pretendard(13, weight: .semibold))
                        .foregroundColor(.filterzGray30)
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Capsule().fill(Color.filterzBlackAccent))
                .overlay(
                    Capsule()
                        .stroke(Color.filterzAccent.opacity(0.55), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(store.isSummarizing)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.filterzBlackBase)
    }

    private var summarySheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.filterzAccent)

                Text("AI 요약")
                    .font(.filterzDisplay(18))
                    .foregroundColor(.filterzGray30)

                Spacer()
            }

            ScrollView {
                Text(store.summaryText ?? "")
                    .font(.pretendard(14, weight: .regular))
                    .foregroundColor(.filterzGray45)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineSpacing(4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.filterzBlackAccent)
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(store.messages.enumerated()), id: \.element.id) { index, message in
                        let isMine = message.senderId == store.currentUserId
                        let showsTimestamp = shouldShowTimestamp(at: index)
                        let showsProfile = !isMine && shouldShowProfile(at: index)
                        let startsGroup = shouldStartGroup(at: index)
                        let endsGroup = shouldEndGroup(at: index)
                        let changesSender = shouldSeparateSenderGroup(at: index)

                        if shouldShowDateSeparator(at: index) {
                            Text(message.createdAt.chatSeparatorDisplay)
                                .font(.pretendard(11, weight: .regular))
                                .foregroundColor(.filterzGray60)
                                .padding(.top, index == 0 ? 8 : 18)
                                .padding(.bottom, 10)
                        }

                        ChatBubbleView(
                            message: message,
                            isMine: isMine,
                            showsTimestamp: showsTimestamp,
                            showsProfile: showsProfile,
                            startsGroup: startsGroup,
                            endsGroup: endsGroup,
                            onProfileTapped: {
                                store.send(.messageProfileTapped(userId: message.senderId))
                            },
                            onImageTapped: { paths, index in
                                store.send(.imageTapped(paths: paths, index: index))
                            },
                            onPDFTapped: { path in
                                store.send(.pdfTapped(path: path))
                            },
                            onImageLoaded: {
                                guard Date() < autoScrollUntil else { return }
                                scrollToBottomTrigger = UUID()
                            }
                        )
                        .id(message.id)
                        .padding(.horizontal, 16)
                        .padding(.top, changesSender ? 14 : (startsGroup ? 8 : 0))
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("chat-bottom")
                        .onAppear {
                            store.send(.latestMessagesReached)
                        }
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            })
            .onChange(of: store.messages.last?.id) { _, _ in
                guard !store.shouldPreserveUnreadPosition else { return }
                if let last = store.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .onChange(of: store.initialScrollTargetId) { _, target in
                guard store.shouldPreserveUnreadPosition, let target else { return }
                DispatchQueue.main.async {
                    proxy.scrollTo(target, anchor: .bottom)
                }
            }
            .onChange(of: scrollToBottomTrigger) { _, _ in
                guard !store.shouldPreserveUnreadPosition else { return }
                if let last = store.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .onAppear {
                autoScrollUntil = Date().addingTimeInterval(5)
                DispatchQueue.main.async {
                    if store.shouldPreserveUnreadPosition,
                       let target = store.initialScrollTargetId {
                        proxy.scrollTo(target, anchor: .bottom)
                        return
                    }
                    if let last = store.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func shouldShowDateSeparator(at index: Int) -> Bool {
        let messages = store.messages
        guard index < messages.count else { return false }
        if index == 0 { return true }
        let current = messages[index]
        let previous = messages[index - 1]
        let calendar = Calendar.current
        return !calendar.isDate(current.createdAt, inSameDayAs: previous.createdAt)
    }

    private func shouldShowProfile(at index: Int) -> Bool {
        let messages = store.messages
        guard index < messages.count else { return false }
        let current = messages[index]
        if index + 1 >= messages.count { return true }
        let next = messages[index + 1]
        return next.senderId != current.senderId
    }

    private func shouldStartGroup(at index: Int) -> Bool {
        let messages = store.messages
        guard index < messages.count else { return false }
        if index == 0 { return true }
        let current = messages[index]
        let previous = messages[index - 1]
        return !isSameMessageGroup(previous, current)
    }

    private func shouldEndGroup(at index: Int) -> Bool {
        let messages = store.messages
        guard index < messages.count else { return false }
        if index + 1 >= messages.count { return true }
        let current = messages[index]
        let next = messages[index + 1]
        return !isSameMessageGroup(current, next)
    }

    private func shouldSeparateSenderGroup(at index: Int) -> Bool {
        let messages = store.messages
        guard index > 0, index < messages.count else { return false }
        return messages[index - 1].senderId != messages[index].senderId
    }

    private func shouldShowTimestamp(at index: Int) -> Bool {
        let messages = store.messages
        guard index < messages.count else { return false }
        let current = messages[index]
        let next = (index + 1 < messages.count) ? messages[index + 1] : nil
        guard let next else { return true }
        return !isSameMessageGroup(current, next)
    }

    private func isSameMessageGroup(_ lhs: ChatMessage, _ rhs: ChatMessage) -> Bool {
        guard lhs.senderId == rhs.senderId else { return false }
        let calendar = Calendar.current
        let lhsMinute = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: lhs.createdAt)
        let rhsMinute = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: rhs.createdAt)
        return lhsMinute == rhsMinute
    }
}
