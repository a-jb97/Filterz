import SwiftUI

struct TodayBannerView: View {
    var currentPage: Int = 1
    var totalPages: Int = 12

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // 배경 이미지 placeholder
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "#1A2A3A"))
                .frame(height: 100)

            // 페이지 컨트롤
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.filterzGray75.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.filterzGray60, lineWidth: 1)
                    )
                    .frame(width: 44, height: 20)

                Text("\(currentPage) / \(totalPages)")
                    .font(.pretendard(10, weight: .medium))
                    .foregroundColor(.filterzGray45)
            }
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
}
