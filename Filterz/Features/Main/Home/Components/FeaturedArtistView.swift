import SwiftUI

struct FeaturedArtistView: View {
    let artist: ArtistItem
    let onFilterTapped: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 섹션 헤더
            Text("오늘의 작가 소개")
                .font(.pretendard(16, weight: .bold))
                .foregroundColor(.filterzGray60)

            // 작가 프로필
            HStack(spacing: 16) {
                AuthenticatedImageView(path: artist.profileImagePath)
                    .frame(width: 72, height: 72)
                    .background(Color.filterzTranslucent)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.filterzTranslucent, lineWidth: 1))

                VStack(alignment: .leading, spacing: 8) {
                    Text(artist.name)
                        .font(.mulgyeolBold(20))
                        .foregroundColor(.filterzGray30)
                    Text(artist.nameEn)
                        .font(.pretendard(16, weight: .medium))
                        .foregroundColor(.filterzGray75)
                }
            }

            // 작품 가로 스크롤
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(artist.filterWorks) { work in
                        AuthenticatedImageView(path: work.imageURL)
                            .frame(width: 120, height: 80)
                            .background(Color(hex: "#2A2A3A"))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .onTapGesture { onFilterTapped(work.id) }
                    }
                }
            }

            // 태그
            HStack(spacing: 4) {
                ForEach(artist.tags, id: \.self) { tag in
                    TagView(text: tag)
                }
            }

            // 인용구 + 소개 텍스트
            VStack(alignment: .leading, spacing: 12) {
                Text(artist.quote)
                    .font(.mulgyeolRegular(14))
                    .foregroundColor(.filterzGray60)

                Text(artist.bio)
                    .font(.pretendard(12, weight: .regular))
                    .foregroundColor(.filterzGray60)
                    .lineSpacing(12 * 0.7)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

private struct TagView: View {
    let text: String

    var body: some View {
        Text("#\(text)")
            .font(.pretendard(12, weight: .medium))
            .foregroundColor(.filterzGray60)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.filterzBlackTurquoise)
            )
    }
}
