import SwiftUI

struct CreatorSection: View {
    let creator: FilterCreator
    var onDMTapped: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            AuthenticatedImageView(path: creator.profileImagePath)
                .frame(width: 48, height: 48)
                .background(Color.filterzBlackTurquoise)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.filterzTranslucent, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(creator.nick)
                    .font(.pretendard(14, weight: .semibold))
                    .foregroundColor(.filterzGray30)
                Text(creator.nick.uppercased())
                    .font(.pretendard(12, weight: .regular))
                    .foregroundColor(.filterzGray60)
            }

            Spacer()

            Button(action: onDMTapped) {
                Image(systemName: "paperplane")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.filterzGray45)
                    .padding(14)
                    .background(
                        Circle()
                            .fill(Color.filterzBlackTurquoise)
                            .overlay(
                                Circle().stroke(Color.filterzTranslucent, lineWidth: 1)
                            )
                    )
            }
        }
    }
}
