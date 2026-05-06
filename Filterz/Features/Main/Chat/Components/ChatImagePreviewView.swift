import SwiftUI

struct ChatImagePreviewView: View {
    let paths: [String]
    let initialIndex: Int
    var onDismiss: () -> Void

    @State private var selectedIndex: Int

    init(paths: [String], initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.paths = paths
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        _selectedIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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
