import SwiftUI

enum FilterCategory: CaseIterable, Equatable, Sendable {
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

    var categoryString: String {
        switch self {
        case .food: return "푸드"
        case .person: return "인물"
        case .landscape: return "풍경"
        case .night: return "야경"
        case .star: return "천문"
        }
    }
}

struct CategoryBarView: View {
    let onCategoryTapped: (FilterCategory) -> Void

    var body: some View {
        VStack(spacing: 0) {
            CategoryFilmPerforationStrip()

            HStack(spacing: 0) {
                ForEach(FilterCategory.allCases, id: \.title) { category in
                    CategoryItemView(category: category)
                        .frame(maxWidth: .infinity)
                        .onTapGesture { onCategoryTapped(category) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            CategoryFilmPerforationStrip()
        }
        .frame(maxWidth: .infinity)
        .background(Color.filterzGray30.opacity(0.9))
        .padding(.top, 8)
        .padding(.bottom, 15)
    }
}

private struct CategoryItemView: View {
    let category: FilterCategory

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.filterzPolaroid)

                Text(category.title)
                    .font(.pretendard(10, weight: .semibold))
                    .foregroundColor(.filterzPolaroid)
            }
            .frame(height: 52)
        }
    }
}

private struct CategoryFilmPerforationStrip: View {
    private let holeCount = 10

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<holeCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.filterzBackground)
                    .frame(width: 14, height: 14)

                if index < holeCount - 1 {
                    Spacer(minLength: 8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }
}
