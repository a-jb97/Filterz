import SwiftUI

struct FilterzTornTapeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        var path = Path()
        path.move(to: CGPoint(x: w * 0.08, y: h * 0.02))
        path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.05))
        path.addLine(to: CGPoint(x: w * 0.42, y: 0))
        path.addLine(to: CGPoint(x: w * 0.64, y: h * 0.04))
        path.addLine(to: CGPoint(x: w * 0.86, y: h * 0.01))
        path.addLine(to: CGPoint(x: w * 0.96, y: h * 0.06))
        path.addLine(to: CGPoint(x: w, y: h * 0.18))
        path.addLine(to: CGPoint(x: w * 0.96, y: h * 0.32))
        path.addLine(to: CGPoint(x: w * 0.99, y: h * 0.48))
        path.addLine(to: CGPoint(x: w * 0.95, y: h * 0.65))
        path.addLine(to: CGPoint(x: w, y: h * 0.82))
        path.addLine(to: CGPoint(x: w * 0.94, y: h * 0.96))
        path.addLine(to: CGPoint(x: w * 0.76, y: h))
        path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.97))
        path.addLine(to: CGPoint(x: w * 0.34, y: h))
        path.addLine(to: CGPoint(x: w * 0.16, y: h * 0.96))
        path.addLine(to: CGPoint(x: w * 0.04, y: h * 0.99))
        path.addLine(to: CGPoint(x: 0, y: h * 0.82))
        path.addLine(to: CGPoint(x: w * 0.04, y: h * 0.66))
        path.addLine(to: CGPoint(x: w * 0.01, y: h * 0.5))
        path.addLine(to: CGPoint(x: w * 0.05, y: h * 0.34))
        path.addLine(to: CGPoint(x: 0, y: h * 0.18))
        path.addLine(to: CGPoint(x: w * 0.08, y: h * 0.02))
        path.closeSubpath()

        return path
    }
}

struct FilterzTornTapeStyle: ViewModifier {
    var font: Font = .pretendard(14, weight: .medium)
    var foregroundColor: Color = .filterzGray30
    var fillColor: Color = .filterzClip
    var strokeColor: Color? = nil
    var horizontalPadding: CGFloat = 13
    var verticalPadding: CGFloat = 7

    func body(content: Content) -> some View {
        let shape = FilterzTornTapeShape()

        content
            .font(font)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                shape
                    .fill(fillColor)
                    .overlay {
                        if let strokeColor {
                            shape.stroke(strokeColor, lineWidth: 1)
                        }
                    }
            )
    }
}

extension View {
    func filterzTornTapeStyle(
        font: Font = .pretendard(14, weight: .medium),
        foregroundColor: Color = .filterzGray30,
        fillColor: Color = .filterzClip,
        strokeColor: Color? = nil,
        horizontalPadding: CGFloat = 13,
        verticalPadding: CGFloat = 7
    ) -> some View {
        modifier(FilterzTornTapeStyle(
            font: font,
            foregroundColor: foregroundColor,
            fillColor: fillColor,
            strokeColor: strokeColor,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding
        ))
    }
}
