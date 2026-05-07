import SwiftUI
import ComposableArchitecture

struct ChatRoomView: View {
    @Bindable var store: StoreOf<ChatRoomFeature>

    var body: some View {
        VStack(spacing: 0) {
            navBar

            messagesList

            ChatInputBar(
                text: Binding(
                    get: { store.draft },
                    set: { store.send(.draftChanged($0)) }
                ),
                pendingImages: store.pickedImages,
                isSending: store.isSending,
                onSend: { store.send(.sendTapped) },
                onImagesPicked: { store.send(.imagesPicked($0)) },
                onImageRemoved: { store.send(.imageRemoved($0)) },
                onImagePrepared: { store.send(.imagePrepared(id: $0, uploadData: $1, thumbnail: $2)) }
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
            "메시지 전송 실패",
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
                            }
                        )
                        .id(message.id)
                        .padding(.horizontal, 16)
                        .padding(.top, changesSender ? 14 : (startsGroup ? 8 : 0))
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: store.messages.count) { _, _ in
                if let last = store.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let last = store.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
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
