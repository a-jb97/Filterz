import SwiftUI

struct ChatImagePreviewView: View {
    let paths: [String]
    let initialIndex: Int
    var onDismiss: () -> Void

    @State private var selectedIndex: Int
    @State private var dragOffset: CGFloat = 0

    init(paths: [String], initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.paths = paths
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        _selectedIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            ZStack {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(paths.enumerated()), id: \.offset) { index, path in
                        ZoomableChatImage(path: path)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()

                VStack {
                    topBar
                    Spacer()
                    if paths.count > 1 {
                        Text("\(selectedIndex + 1) / \(paths.count)")
                            .font(.pretendard(13, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.black.opacity(0.45)))
                            .padding(.bottom, 18)
                    }
                }
            }
            .offset(y: dragOffset)
        }
        .simultaneousGesture(dismissDragGesture)
    }

    private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.65), Color.black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 96),
            alignment: .top
        )
    }

    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
                guard isDownwardDismissDrag(value) else { return }
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                guard isDownwardDismissDrag(value) else {
                    resetDragOffset()
                    return
                }

                if shouldDismiss(for: value) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        dragOffset = 520
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        onDismiss()
                    }
                } else {
                    resetDragOffset()
                }
            }
    }

    private var backgroundOpacity: Double {
        max(0.35, 1 - Double(dragOffset / 420))
    }

    private func isDownwardDismissDrag(_ value: DragGesture.Value) -> Bool {
        let verticalDistance = value.translation.height
        let horizontalDistance = abs(value.translation.width)

        return verticalDistance > 0 && verticalDistance > horizontalDistance * 1.25
    }

    private func shouldDismiss(for value: DragGesture.Value) -> Bool {
        value.translation.height > 120 || value.predictedEndTranslation.height > 220
    }

    private func resetDragOffset() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            dragOffset = 0
        }
    }
}

private struct ZoomableChatImage: View {
    let path: String

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        AuthenticatedImageView(path: path, contentMode: .fit)
            .scaleEffect(scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(max(lastScale * value, 1), 4)
                    }
                    .onEnded { _ in
                        lastScale = scale
                        if scale < 1.05 {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                scale = 1
                                lastScale = 1
                            }
                        }
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    if scale > 1 {
                        scale = 1
                        lastScale = 1
                    } else {
                        scale = 2
                        lastScale = 2
                    }
                }
            }
    }
}
