import SwiftUI

extension Color {
    static let filterzBackground      = Color(hex: "#FFFFFA")
    static let filterzGray30         = Color(hex: "#151100")
    static let filterzAccent         = Color(hex: "#795027")
    static let filterzAccentDeep     = Color(hex: "#FFB800")
    static let filterzSurface        = Color(hex: "#1A1A1A")
    static let filterzBorder         = Color(hex: "#2A2A2A")
    static let filterzTextSecondary  = Color(hex: "#8A8A8A")
    static let filterzError          = Color(hex: "#FF4B4B")
    static let filterzGray45         = Color(hex: "#D8D6D7")
    static let filterzDeepSprout      = Color(hex: "#2d1b09")
    static let filterzGray90          = Color(hex: "#434347")
    static let filterzTranslucent     = Color(hex: "#6A6A6E").opacity(0.5)

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
