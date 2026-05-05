import SwiftUI

private let imageCache = NSCache<NSString, UIImage>()

struct AuthenticatedImageView: View {
    let path: String?
    var contentMode: ContentMode = .fill
    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Color.clear
            }
        }
        .task(id: path) { await loadImage(for: path) }
    }

    private func loadImage(for path: String?) async {
        guard let path else {
            image = nil
            return
        }

        if let cached = imageCache.object(forKey: path as NSString) {
            image = cached
            return
        }

        image = nil

        let urlString = path.hasPrefix("http") ? path : APIKey.baseURL + path
        guard let url = URL(string: urlString) else {
            return
        }
        var request = URLRequest(url: url)
        request.setValue(APIKey.apiKey, forHTTPHeaderField: "SeSACKey")
        request.setValue(APIKey.accessToken, forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let loaded = UIImage(data: data),
              !Task.isCancelled,
              self.path == path else { return }

        imageCache.setObject(loaded, forKey: path as NSString)
        image = loaded
    }
}
