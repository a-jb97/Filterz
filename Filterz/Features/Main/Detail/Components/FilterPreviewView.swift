import SwiftUI

struct FilterPreviewView: View {
    let afterImageURL: String?
    let beforeImageURL: String?
    let sliderOffset: CGFloat
    let onSliderChanged: (CGFloat) -> Void

    var body: some View {
        GeometryReader { geo in
            let revealX = geo.size.width * sliderOffset

            VStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    AuthenticatedImageView(path: afterImageURL)
                        .frame(width: geo.size.width, height: 400)
                        .clipped()

                    AuthenticatedImageView(path: beforeImageURL ?? afterImageURL)
                        .frame(width: geo.size.width, height: 400)
                        .clipped()
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: max(0, revealX), height: 400)
                        }
                }
                .frame(width: geo.size.width, height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                AfterBeforeLabelRow()
                    .offset(x: revealX - geo.size.width / 2)
                    .gesture(
                        DragGesture(coordinateSpace: .named("preview"))
                            .onChanged { value in
                                let newOffset = value.location.x / geo.size.width
                                onSliderChanged(max(0, min(1, newOffset)))
                            }
                    )
            }
        }
        .frame(height: 444)
        .coordinateSpace(name: "preview")
    }
}

// MARK: - After/Before Labels

struct AfterBeforeLabelRow: View {
    var body: some View {
        HStack(spacing: 8) {
            label("After")
            Image(systemName: "arrow.up.circle.fill")
                .foregroundColor(Color.filterzGray60)
                .font(.system(size: 20))
            label("Before")
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.pretendard(13, weight: .bold))
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .frame(minWidth: 80)
            .background(
                Capsule()
                    .fill(Color.filterzAccent)
            )
    }
}
