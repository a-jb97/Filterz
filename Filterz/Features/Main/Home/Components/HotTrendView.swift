import SwiftUI

struct HotTrendView: View {
    let filters: [HotFilterItem]
    var onFilterTapped: (String) -> Void = { _ in }

    @State private var focusedID: String?

    private let cardWidth: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("핫 트렌드")
                .font(.pretendard(16, weight: .bold))
                .foregroundColor(.filterzGray60)
                .padding(.horizontal, 20)

            GeometryReader { geo in
                let sidePad = max(0, (geo.size.width - cardWidth) / 2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters) { filter in
                            HotFilterCardView(
                                item: filter,
                                isFocused: filter.id == focusedID,
                                onTap: { onFilterTapped(filter.id) }
                            )
                            .id(filter.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $focusedID)
                .contentMargins(.horizontal, sidePad, for: .scrollContent)
            }
            .frame(height: 240)
        }
        .padding(.top, 20)
        .onChange(of: filters) { _, newFilters in
            guard focusedID == nil, let first = newFilters.first else { return }
            focusedID = first.id
        }
    }
}
