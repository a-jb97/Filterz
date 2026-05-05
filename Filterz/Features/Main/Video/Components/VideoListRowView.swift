import SwiftUI

struct VideoListRowView: View {
    let item: VideoItem
    let isLoadingStream: Bool
    let onTapped: () -> Void
    let onLikeTapped: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnailView

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.filterzDisplay(18))
                    .foregroundColor(.filterzGray30)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(item.description)
                    .font(.pretendard(13, weight: .regular))
                    .foregroundColor(.filterzGray75)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    metadataLabel(systemName: "eye.fill", text: "\(item.viewCount)")
                    metadataLabel(systemName: "clock.fill", text: item.durationText)
                    if let quality = item.availableQualities.first {
                        Text(quality)
                            .font(.pretendard(12, weight: .semibold))
                            .foregroundColor(.filterzAccent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.filterzBlackAccent))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onLikeTapped) {
                VStack(spacing: 4) {
                    Image(systemName: item.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(item.isLiked ? .red : .filterzGray45)

                    Text("\(item.likeCount)")
                        .font(.pretendard(12, weight: .semibold))
                        .foregroundColor(.filterzGray75)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTapped)
    }

    private var thumbnailView: some View {
        ZStack {
            AuthenticatedImageView(path: item.thumbnailURL, contentMode: .fill)
                .frame(width: 100, height: 120)
                .background(Color.filterzBlackAccent)
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0.15), .black.opacity(0.52)],
                startPoint: .top,
                endPoint: .bottom
            )

            if isLoadingStream {
                ProgressView()
                    .tint(.filterzGray30)
            } else {
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.filterzGray30)
                    .padding(10)
                    .background(Circle().fill(Color.black.opacity(0.45)))
            }
        }
        .frame(width: 100, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func metadataLabel(systemName: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.pretendard(12, weight: .medium))
        }
        .foregroundColor(.filterzGray60)
    }
}
