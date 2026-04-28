import SwiftUI

struct FilterPreviewView: View {
    let afterImageURL: String?
    let beforeImageURL: String?
    let sliderOffset: CGFloat
    let onSliderChanged: (CGFloat) -> Void

    var body: some View {
        GeometryReader { geo in
            let revealX = geo.size.width * sliderOffset

            ZStack(alignment: .leading) {
                AuthenticatedImageView(path: afterImageURL)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                AuthenticatedImageView(path: beforeImageURL ?? afterImageURL)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: max(0, revealX), height: geo.size.height)
                    }

                dragHandle
                    .offset(x: max(0, revealX - 20))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newOffset = (revealX + value.translation.width) / geo.size.width
                                onSliderChanged(newOffset)
                            }
                    )
            }
        }
        .frame(height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var dragHandle: some View {
        ZStack {
            Circle()
                .fill(Color.filterzGray45.opacity(0.9))
                .frame(width: 40, height: 40)
            Image(systemName: "arrow.left.and.right")
                .foregroundColor(Color.filterzBlackBase)
                .font(.system(size: 13, weight: .bold))
        }
        .frame(width: 40, height: 40)
    }
}

// MARK: - After/Before Labels

struct AfterBeforeLabelRow: View {
    let sliderOffset: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            label("After", isActive: sliderOffset < 0.5)
            Image(systemName: "arrow.up.circle.fill")
                .foregroundColor(Color.filterzGray60)
                .font(.system(size: 20))
            label("Before", isActive: sliderOffset >= 0.5)
        }
    }

    private func label(_ text: String, isActive: Bool) -> some View {
        Text(text)
            .font(.pretendard(13, weight: isActive ? .bold : .medium))
            .foregroundColor(isActive ? .filterzGray30 : .filterzGray75)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isActive ? Color.filterzBrightTurquoise : Color.filterzBlackTurquoise)
            )
    }
}
