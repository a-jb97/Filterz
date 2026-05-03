import SwiftUI

struct HotTrendView: View {
    let filters: [HotFilterItem]
    var onFilterTapped: (String) -> Void = { _ in }

    @State private var focusedID: String?
    @State private var scrollPositionID: String?

    private let cardWidth: CGFloat = 200
    private let coordinateSpaceName = "HotTrendScrollCoordinateSpace"

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
                                onTap: {
                                    focusedID = filter.id
                                    scrollPositionID = filter.id
                                    onFilterTapped(filter.id)
                                }
                            )
                            .id(filter.id)
                            .background {
                                GeometryReader { cardGeo in
                                    Color.clear.preference(
                                        key: HotTrendCardCenterPreferenceKey.self,
                                        value: [
                                            filter.id: cardGeo.frame(in: .named(coordinateSpaceName)).midX
                                        ]
                                    )
                                }
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $scrollPositionID)
                .contentMargins(.horizontal, sidePad, for: .scrollContent)
                .coordinateSpace(name: coordinateSpaceName)
                .onPreferenceChange(HotTrendCardCenterPreferenceKey.self) { centers in
                    updateFocusedID(from: centers, viewportCenterX: geo.size.width / 2)
                }
            }
            .frame(height: 240)
        }
        .padding(.top, 20)
        .onAppear {
            syncFocus(with: filters)
        }
        .onChange(of: filters) { _, newFilters in
            syncFocus(with: newFilters)
        }
    }

    private func syncFocus(with filters: [HotFilterItem]) {
        guard let firstID = filters.first?.id else {
            focusedID = nil
            scrollPositionID = nil
            return
        }

        if let focusedID, filters.contains(where: { $0.id == focusedID }) {
            if scrollPositionID == nil {
                scrollPositionID = focusedID
            }
            return
        }

        focusedID = firstID
        scrollPositionID = firstID
    }

    private func updateFocusedID(
        from centers: [String: CGFloat],
        viewportCenterX: CGFloat
    ) {
        guard let closest = centers.min(by: {
            abs($0.value - viewportCenterX) < abs($1.value - viewportCenterX)
        }) else { return }

        if focusedID != closest.key {
            focusedID = closest.key
        }
    }
}

private struct HotTrendCardCenterPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
