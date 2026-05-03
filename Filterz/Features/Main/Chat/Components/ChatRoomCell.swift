import SwiftUI

struct ChatRoomCell: View {
    let room: ChatRoom

    var body: some View {
        HStack(spacing: 12) {
            AuthenticatedImageView(path: room.opponentProfilePath)
                .frame(width: 56, height: 56)
                .background(Color.filterzBlackTurquoise)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.filterzTranslucent, lineWidth: 1))

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

            Spacer(minLength: 12)

            if let date = room.lastMessageAt {
                Text(date.chatDisplay)
                    .font(.pretendard(11, weight: .regular))
                    .foregroundColor(.filterzGray75)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
