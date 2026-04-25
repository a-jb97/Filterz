import SwiftUI

private enum FilterCategory: CaseIterable {
    case food, person, landscape, night, star

    var title: String {
        switch self {
        case .food: return "푸드"
        case .person: return "인물"
        case .landscape: return "풍경"
        case .night: return "야경"
        case .star: return "별"
        }
    }

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .person: return "person"
        case .landscape: return "mountain.2"
        case .night: return "moon.stars"
        case .star: return "sparkles"
        }
    }
}

struct CategoryBarView: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(FilterCategory.allCases, id: \.title) { category in
                CategoryItemView(category: category)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
    }
}

private struct CategoryItemView: View {
    let category: FilterCategory

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.filterzTranslucent)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.filterzTranslucent, lineWidth: 1)
                )
                .frame(width: 56, height: 56)

            VStack(spacing: 2) {
                Image(systemName: category.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.filterzGray60)

                Text(category.title)
                    .font(.pretendard(10, weight: .semibold))
                    .foregroundColor(.filterzGray60)
            }
        }
    }
}
