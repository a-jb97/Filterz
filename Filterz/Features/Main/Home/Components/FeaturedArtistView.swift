import SwiftUI

struct FeaturedArtistView: View {
    let artist: ArtistItem
    let onProfileTapped: () -> Void
    let onFilterTapped: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 섹션 헤더
            Text("오늘의 작가 소개")
                .font(.pretendard(16, weight: .bold))
                .foregroundColor(.filterzGray30)

            // 작가 프로필
            Button(action: onProfileTapped) {
                HStack(spacing: 16) {
                    artistProfileImage

                    VStack(alignment: .leading, spacing: 8) {
                        Text(artist.name)
                            .font(.mulgyeolBold(20))
                            .foregroundColor(.filterzGray30)
                        Text(artist.nameEn)
                            .font(.pretendard(16, weight: .medium))
                            .foregroundColor(.filterzGray30)
                    }
                }
            }
            .buttonStyle(.plain)

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
                    .foregroundColor(.filterzGray30)

                Text(artist.bio)
                    .font(.pretendard(12, weight: .regular))
                    .foregroundColor(.filterzGray30)
                    .lineSpacing(12 * 0.7)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 20)
    }

    private var artistProfileImage: some View {
        ZStack {
            Color(hex: "#E8EDF1")

            AuthenticatedImageView(path: artist.profileImagePath)
                .scaledToFill()

            if artist.profileImagePath == nil {
                Image(systemName: "person.fill")
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(.filterzGray30)
            }
        }
        .frame(width: 60, height: 74)
        .clipped()
        .padding(.top, 7)
        .padding(.horizontal, 7)
        .padding(.bottom, 10)
        .background(
            Color.filterzPolaroid
                .shadow(color: Color.black.opacity(0.16), radius: 6, x: 3, y: 4)
        )
        .overlay(
            Rectangle()
                .stroke(Color.filterzGray45.opacity(0.85), lineWidth: 1)
        )
    }
}

private struct TagView: View {
    let text: String

    var body: some View {
        Text("#\(displayHashTag(text))")
            .filterzTornTapeStyle()
    }
}
