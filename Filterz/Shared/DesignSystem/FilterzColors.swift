import SwiftUI

extension Color {
    static let filterzBackground    = Color(hex: "#000000")
    static let filterzAccent        = Color(hex: "#FFE100")
    static let filterzSurface       = Color(hex: "#1A1A1A")
    static let filterzBorder        = Color(hex: "#2A2A2A")
    static let filterzTextPrimary   = Color.white
    static let filterzTextSecondary = Color(hex: "#8A8A8A")
    static let filterzError         = Color(hex: "#FF4B4B")

    // Figma 디자인 시스템 색상
    static let filterzBlackBase      = Color(hex: "#0B0B0B")   // GrayScale/100
    static let filterzGray30         = Color(hex: "#EAEAEA")   // GrayScale/30 - 1차 텍스트
    static let filterzGray45         = Color(hex: "#D8D6D7")   // GrayScale/45
    static let filterzGray60         = Color(hex: "#ABABAE")   // GrayScale/60 - 2차 텍스트
    static let filterzGray75         = Color(hex: "#6A6A6E")   // GrayScale/75 - 비활성
    static let filterzBlackTurquoise = Color(hex: "#1F2527")   // 태그 배경
    static let filterzTranslucent    = Color(hex: "#6A6A6E").opacity(0.5)

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
