import SwiftUI

struct SocialLoginButton: View {
    enum Provider {
        case kakao, apple

        var backgroundColor: Color {
            switch self {
            case .kakao: return Color(hex: "#FEE500")
            case .apple: return .black
            }
        }

        var foregroundColor: Color {
            switch self {
            case .kakao: return Color(hex: "#3A1D1D")
            case .apple: return Color.white
            }
        }

        var iconName: String {
            switch self {
            case .kakao: return "message.fill"
            case .apple: return "apple.logo"
            }
        }

        var title: String {
            switch self {
            case .kakao: return "카카오로 로그인"
            case .apple: return "Apple로 로그인"
            }
        }
    }

    let provider: Provider
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 18))
                Text(provider.title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(provider.foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(provider.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
