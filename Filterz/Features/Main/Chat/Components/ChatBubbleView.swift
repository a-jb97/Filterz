import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let isMine: Bool
    let showsTimestamp: Bool
    let showsProfile: Bool
    let startsGroup: Bool
    let endsGroup: Bool
    let profileImagePath: String?
    var onProfileTapped: () -> Void = {}
    var onImageTapped: (_ paths: [String], _ index: Int) -> Void = { _, _ in }
    var onPDFTapped: (_ path: String) -> Void = { _ in }
    var onImageLoaded: (() -> Void)? = nil

    private var maxWidth: CGFloat {
        UIScreen.main.bounds.width * 0.7
    }

    var body: some View {
        if isMine {
            HStack(alignment: .bottom) {
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 3) {
                    if showsTimestamp { timestampView }
                    bubbleContent
                }
                .padding(.leading, 56)
            }
        } else {
            HStack(alignment: .bottom, spacing: 8) {
                profileColumn
                HStack(alignment: .bottom, spacing: 3) {
                    bubbleContent
                    if showsTimestamp { timestampView }
                }
                Spacer(minLength: 0)
            }
            .padding(.trailing, 56)
        }
    }

    private var profileColumn: some View {
        Group {
            if showsProfile {
                Button(action: onProfileTapped) {
                    AuthenticatedImageView(path: profileImagePath)
                        .frame(width: 32, height: 32)
                        .background(Color.filterzBlackAccent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 32, height: 32)
            }
        }
    }

    private var timestampView: some View {
        Text(message.createdAt.chatTimeDisplay)
            .font(.pretendard(11, weight: .regular))
            .foregroundColor(.filterzGray60)
            .lineLimit(1)
            .fixedSize()
            .padding(.bottom, 1)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 6) {
            if !message.imageFiles.isEmpty {
                ChatImageGrid(
                    paths: message.imageFiles,
                    onImageTapped: { index in
                        onImageTapped(message.imageFiles, index)
                    },
                    onImageLoaded: onImageLoaded
                )
                .frame(maxWidth: maxWidth)
            }
            if !message.pdfFiles.isEmpty {
                ChatPDFListView(paths: message.pdfFiles, onPDFTapped: onPDFTapped)
                    .frame(maxWidth: maxWidth)
            }
            if let content = message.content, !content.isEmpty {
                Text(content)
                    .font(.pretendard(14, weight: .regular))
                    .foregroundColor(isMine ? .filterzBlackBase : .filterzGray30)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .clipShape(bubbleShape)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }
        }
    }

    private var bubbleShape: UnevenRoundedRectangle {
        let large: CGFloat = 20
        let tight: CGFloat = 6

        if isMine {
            return UnevenRoundedRectangle(
                topLeadingRadius: large,
                bottomLeadingRadius: large,
                bottomTrailingRadius: endsGroup ? large : tight,
                topTrailingRadius: startsGroup ? large : tight,
                style: .continuous
            )
        } else {
            return UnevenRoundedRectangle(
                topLeadingRadius: startsGroup ? large : tight,
                bottomLeadingRadius: endsGroup ? large : tight,
                bottomTrailingRadius: large,
                topTrailingRadius: large,
                style: .continuous
            )
        }
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
            Color.filterzBlackAccent
        }
    }
}
