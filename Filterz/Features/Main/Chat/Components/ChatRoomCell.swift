import SwiftUI

struct ChatRoomCell: View {
    let room: ChatRoom
    let onRoomTapped: () -> Void
    let onProfileTapped: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onProfileTapped) {
                AuthenticatedImageView(path: room.opponentProfilePath)
                    .frame(width: 56, height: 56)
                    .background(Color.filterzBlackAccent)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.filterzTranslucent, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button(action: onRoomTapped) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(room.opponentNick)
                            .font(.pretendard(15, weight: .semibold))
                            .foregroundColor(.filterzGray30)
                            .lineLimit(1)
                        Text(room.lastMessageContent ?? "메시지를 보내보세요")
                            .font(.pretendard(13, weight: .regular))
                            .foregroundColor(.filterzGray60)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 6) {
                        if let date = room.lastMessageAt {
                            Text(date.chatDisplay)
                                .font(.pretendard(11, weight: .regular))
                                .foregroundColor(.filterzGray75)
                        }

                        if room.unreadCount > 0 {
                            Text(unreadBadgeText)
                                .font(.pretendard(11, weight: .semibold))
                                .foregroundColor(.filterzBlackAccent)
                                .frame(minWidth: 20, minHeight: 20)
                                .padding(.horizontal, room.unreadCount > 9 ? 6 : 0)
                                .background(Capsule().fill(Color.filterzAccent))
                                .accessibilityLabel("읽지 않은 메시지 \(room.unreadCount)개")
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.filterzGray75)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var unreadBadgeText: String {
        room.unreadCount > 99 ? "99+" : "\(room.unreadCount)"
    }
}
