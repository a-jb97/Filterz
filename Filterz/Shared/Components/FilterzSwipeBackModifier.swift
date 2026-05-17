import SwiftUI

extension View {
    func filterzSwipeBack(
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        modifier(FilterzSwipeBackModifier(isEnabled: isEnabled, action: action))
    }
}

private struct FilterzSwipeBackModifier: ViewModifier {
    let isEnabled: Bool
    let action: () -> Void

    private let edgeWidth: CGFloat = 24
    private let triggerDistance: CGFloat = 80
    private let minimumDistance: CGFloat = 30

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .simultaneousGesture(swipeBackGesture)
    }

    private var swipeBackGesture: some Gesture {
        DragGesture(minimumDistance: minimumDistance, coordinateSpace: .global)
            .onEnded { value in
                guard isEnabled else { return }

                let horizontalDistance = value.translation.width
                let verticalDistance = abs(value.translation.height)

                guard value.startLocation.x <= edgeWidth,
                      horizontalDistance >= triggerDistance,
                      horizontalDistance > verticalDistance * 1.2
                else { return }

                action()
            }
    }
}
