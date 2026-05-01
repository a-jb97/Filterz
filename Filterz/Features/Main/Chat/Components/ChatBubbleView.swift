import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let isMine: Bool
    let showsTimestamp: Bool
    let showsProfile: Bool

    private var maxWidth: CGFloat {
        UIScreen.main.bounds.width * 0.65
    }

    var body: some View {
        if isMine {
            HStack(alignment: .bottom) {
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 4) {
                    if showsTimestamp { timestampView }
                    bubbleContent
                }
            }
        } else {
            HStack(alignment: .bottom, spacing: 8) {
                profileColumn
                HStack(alignment: .bottom, spacing: 4) {
                    bubbleContent
                    if showsTimestamp { timestampView }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var profileColumn: some View {
        Group {
            if showsProfile {
                AuthenticatedImageView(path: message.senderProfilePath)
                    .frame(width: 32, height: 32)
                    .background(Color.filterzBlackTurquoise)
                    .clipShape(Circle())
            } else {
                Color.clear.frame(width: 32, height: 32)
            }
        }
    }

    private var timestampView: some View {
        Text(message.createdAt.chatDisplay)
            .font(.pretendard(11, weight: .regular))
            .foregroundColor(.filterzGray60)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 6) {
            if !message.files.isEmpty {
                ChatImageGrid(paths: message.files)
                    .frame(maxWidth: maxWidth)
            }
            if let content = message.content, !content.isEmpty {
                Text(content)
                    .font(.pretendard(14, weight: .regular))
                    .foregroundColor(isMine ? .filterzBlackBase : .filterzGray30)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: maxWidth, alignment: isMine ? .trailing : .leading)
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isMine {
            LinearGradient(
                colors: [Color.filterzAccent, Color.filterzAccentDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.filterzBlackTurquoise
        }
    }
}
