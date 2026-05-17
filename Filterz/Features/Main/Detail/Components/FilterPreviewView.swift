import SwiftUI

struct FilterPreviewView: View {
    let afterImageURL: String?
    let beforeImageURL: String?
    let values: FilterAdjustmentValues
    let sliderOffset: CGFloat
    let onSliderChanged: (CGFloat) -> Void
    @State private var originalImage: UIImage?
    @State private var filteredImage: UIImage?
    @State private var renderSource: FilterImageRenderer.PreviewSource?
    @State private var serverAfterImage: UIImage?
    @State private var serverBeforeImage: UIImage?

    var body: some View {
        GeometryReader { geo in
            let revealX = geo.size.width * sliderOffset

            VStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    if beforeImageURL != nil {
                        serverComparisonImage(revealX: revealX, width: geo.size.width)
                    } else {
                        renderedComparisonImage(revealX: revealX, width: geo.size.width)
                    }
                }
                .frame(width: geo.size.width, height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 5))

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
        .task(id: previewTaskID) { await loadPreviewImages() }
        .onChange(of: values) { _, _ in
            Task { await renderFilteredImage() }
        }
    }

    @ViewBuilder
    private func serverComparisonImage(revealX: CGFloat, width: CGFloat) -> some View {
        previewImage(serverBeforeImage ?? serverAfterImage, width: width)

        previewImage(serverAfterImage, width: width)
            .mask(alignment: .leading) {
                Rectangle()
                    .frame(width: max(0, revealX), height: 400)
            }
    }

    private var previewTaskID: String {
        "\(afterImageURL ?? "")|\(beforeImageURL ?? "")"
    }

    @ViewBuilder
    private func renderedComparisonImage(revealX: CGFloat, width: CGFloat) -> some View {
        previewImage(originalImage, width: width)

        previewImage(filteredImage ?? originalImage, width: width)
            .mask(alignment: .leading) {
                Rectangle()
                    .frame(width: max(0, revealX), height: 400)
            }
    }

    @ViewBuilder
    private func previewImage(_ image: UIImage?, width: CGFloat) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: 400)
                .clipped()
        } else {
            Color.filterzSurface
                .frame(width: width, height: 400)
                .overlay(ProgressView().tint(Color.filterzGray30))
        }
    }

    private func loadPreviewImages() async {
        if beforeImageURL != nil {
            await loadServerComparisonImages()
            return
        }

        guard let data = try? await loadImageData(path: afterImageURL),
              let source = FilterImageRenderer.makePreviewSource(from: data, maxSide: 900)
        else {
            originalImage = nil
            filteredImage = nil
            renderSource = nil
            return
        }

        renderSource = source
        originalImage = source.image
        filteredImage = await Task.detached(priority: .userInitiated) {
            return FilterImageRenderer.previewImage(from: source, values: values)
        }.value
    }

    private func renderFilteredImage() async {
        guard beforeImageURL == nil else { return }
        let source = renderSource
        filteredImage = await Task.detached(priority: .userInitiated) {
            guard let source else { return nil }
            return FilterImageRenderer.previewImage(from: source, values: values)
        }.value
    }

    private func loadServerComparisonImages() async {
        guard let afterData = try? await loadImageData(path: afterImageURL),
              let beforeData = try? await loadImageData(path: beforeImageURL),
              let afterImage = UIImage(data: afterData),
              let beforeImage = UIImage(data: beforeData)
        else {
            serverAfterImage = nil
            serverBeforeImage = nil
            return
        }

        let normalizedPair = await Task.detached(priority: .userInitiated) {
            let targetSize = CGSize(width: 900, height: 900)
            return (
                afterImage.normalizedForComparison(targetSize: targetSize),
                beforeImage.normalizedForComparison(targetSize: targetSize)
            )
        }.value

        serverAfterImage = normalizedPair.0
        serverBeforeImage = normalizedPair.1
    }
}

private func loadImageData(path: String?) async throws -> Data {
    guard let path, let url = URL(string: APIKey.baseURL + path) else {
        throw URLError(.badURL)
    }
    var request = URLRequest(url: url)
    request.setValue(APIKey.apiKey, forHTTPHeaderField: "SeSACKey")
    request.setValue(APIKey.accessToken, forHTTPHeaderField: "Authorization")
    let (data, _) = try await URLSession.shared.data(for: request)
    return data
}

private extension UIImage {
    nonisolated func normalizedForComparison(targetSize: CGSize) -> UIImage {
        let source = normalizedOrientation()
        let sourceSize = source.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return source }

        let scale = max(targetSize.width / sourceSize.width, targetSize.height / sourceSize.height)
        let drawSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let drawOrigin = CGPoint(
            x: (targetSize.width - drawSize.width) / 2,
            y: (targetSize.height - drawSize.height) / 2
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            source.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        }
    }

    nonisolated private func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - After/Before Labels

struct AfterBeforeLabelRow: View {
    var body: some View {
        HStack(spacing: 8) {
            label("After")
            Image(systemName: "arrow.up.circle.fill")
                .foregroundColor(Color.filterzGray30)
                .font(.system(size: 20))
            label("Before")
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.pretendard(13, weight: .bold))
            .foregroundColor(Color.filterzBackground)
            .padding(.horizontal, 8.4)
            .padding(.vertical, 5)
            .frame(minWidth: 56)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.filterzAccent)
            )
    }
}
