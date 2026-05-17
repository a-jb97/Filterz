import SwiftUI

struct AppliedFilterPreviewView: View {
    let imageData: Data
    let isSaving: Bool
    var onApply: () -> Void
    var onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
            }
            .padding(.top, windowSafeAreaTop)
            .background {
                ZoomableAppliedImage(imageData: imageData)
                    .ignoresSafeArea()
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

            Button(action: onApply) {
                ZStack {
                    Text("적용")
                        .font(.pretendard(15, weight: .semibold))
                        .opacity(isSaving ? 0 : 1)

                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .foregroundColor(.white)
                .frame(minWidth: 56, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.65), Color.black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
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

    private var windowSafeAreaTop: CGFloat {
        UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .keyWindow?
            .safeAreaInsets.top ?? 0
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

private struct ZoomableAppliedImage: View {
    let imageData: Data

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        Group {
            if let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.black
            }
        }
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
