import SwiftUI

struct HotTrendView: View {
    let filters: [HotFilterItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("핫 트렌드")
                .font(.pretendard(16, weight: .bold))
                .foregroundColor(.filterzGray60)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(filters.enumerated()), id: \.element.id) { index, filter in
                        HotFilterCardView(
                            item: filter,
                            isCenter: index == 1
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 20)
    }
}
