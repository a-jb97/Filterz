import SwiftUI

struct FilterPreviewView: View {
    let afterImageURL: String?
    let beforeImageURL: String?
    let values: FilterAdjustmentValues
    let sliderOffset: CGFloat
    let onSliderChanged: (CGFloat) -> Void
    @State private var originalImage: UIImage?
    @State private var filteredImage: UIImage?

    var body: some View {
        GeometryReader { geo in
            let revealX = geo.size.width * sliderOffset

            VStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    if beforeImageURL != nil {
                        serverComparisonImage(revealX: revealX)
                    } else {
                        renderedComparisonImage(revealX: revealX)
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
        .task(id: afterImageURL) { await loadPreviewImages() }
        .onChange(of: values) { _, _ in
            Task { await renderFilteredImage() }
        }
    }

    @ViewBuilder
    private func serverComparisonImage(revealX: CGFloat) -> some View {
        AuthenticatedImageView(path: afterImageURL)
            .frame(maxWidth: .infinity, minHeight: 400, maxHeight: 400)
            .clipped()

        AuthenticatedImageView(path: beforeImageURL ?? afterImageURL)
            .frame(maxWidth: .infinity, minHeight: 400, maxHeight: 400)
            .clipped()
            .mask(alignment: .leading) {
                Rectangle()
                    .frame(width: max(0, revealX), height: 400)
            }
    }

    @ViewBuilder
    private func renderedComparisonImage(revealX: CGFloat) -> some View {
        previewImage(originalImage)

        previewImage(filteredImage ?? originalImage)
            .mask(alignment: .leading) {
                Rectangle()
                    .frame(width: max(0, revealX), height: 400)
            }
    }

    @ViewBuilder
    private func previewImage(_ image: UIImage?) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, minHeight: 400, maxHeight: 400)
                .clipped()
        } else {
            Color.filterzSurface
                .frame(maxWidth: .infinity, minHeight: 400, maxHeight: 400)
                .overlay(ProgressView().tint(Color.filterzGray60))
        }
    }

    private func loadPreviewImages() async {
        guard beforeImageURL == nil else { return }
        guard let data = try? await loadImageData(path: afterImageURL),
              let image = UIImage(data: data)
        else {
            originalImage = nil
            filteredImage = nil
            return
        }

        originalImage = image
        filteredImage = await Task.detached(priority: .userInitiated) {
            guard let source = FilterImageRenderer.makePreviewSource(from: image, maxSide: 900) else {
                return image
            }
            return FilterImageRenderer.previewImage(from: source, values: values)
        }.value
    }

    private func renderFilteredImage() async {
        guard beforeImageURL == nil else { return }
        let fallbackImage = originalImage
        filteredImage = await Task.detached(priority: .userInitiated) {
            guard let fallbackImage,
                  let source = FilterImageRenderer.makePreviewSource(from: fallbackImage, maxSide: 900) else {
                return fallbackImage
            }
            return FilterImageRenderer.previewImage(from: source, values: values)
        }.value
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
