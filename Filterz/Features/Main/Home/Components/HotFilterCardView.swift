import SwiftUI

struct HotFilterCardView: View {
    let item: HotFilterItem
    var isCenter: Bool = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 배경 이미지 placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#2A2A3A"))
                .frame(width: 200, height: 240)

            // 필터 이름 (좌상단)
            Text(item.name)
                .font(.mulgyeolRegular(14))
                .foregroundColor(.filterzGray30)
                .padding(.top, 8)
                .padding(.leading, 12)

            // 좋아요 수 (우하단)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundColor(.filterzGray30)
                        Text("\(item.likeCount)")
                            .font(.pretendard(12, weight: .semibold))
                            .foregroundColor(.filterzGray30)
                    }
                    .padding(.trailing, 10)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(width: 200, height: 240)
        .opacity(isCenter ? 1.0 : 0.3)
    }
}
