import SwiftUI

extension Font {
    static func filterzDisplay(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold)
    }

    static func filterzHeadline() -> Font {
        .system(size: 28, weight: .bold)
    }

    static func filterzBody() -> Font {
        .system(size: 16, weight: .regular)
    }

    static func filterzCaption() -> Font {
        .system(size: 13, weight: .regular)
    }
}
