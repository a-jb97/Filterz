import SwiftUI

struct CreatorSection: View {
    let creator: FilterCreator
    let showsDMButton: Bool
    var onProfileTapped: () -> Void = {}
    var onDMTapped: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onProfileTapped) {
                HStack(spacing: 12) {
                    AuthenticatedImageView(path: creator.profileImagePath)
                        .frame(width: 48, height: 48)
                        .background(Color.filterzBlackAccent)
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
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if showsDMButton {
                Button(action: onDMTapped) {
                    Image(systemName: "paperplane")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.filterzGray45)
                        .padding(14)
                        .background(
                            Circle()
                                .fill(Color.filterzBlackAccent)
                                .overlay(
                                    Circle().stroke(Color.filterzTranslucent, lineWidth: 1)
                                )
                        )
                }
            }
        }
    }
}
