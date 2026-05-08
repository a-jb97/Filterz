import ComposableArchitecture
import Foundation

enum ImageQualityOption: String, CaseIterable, Sendable {
    case original = "original"
    case high = "high"
    case low = "low"

    var displayName: String {
        switch self {
        case .original: return "원본"
        case .high:     return "고화질"
        case .low:      return "저화질"
        }
    }

    var qualityDescription: String {
        switch self {
        case .original: return "원본 그대로 첨부"
        case .high:     return "원본 대비 70% 용량"
        case .low:      return "원본 대비 40% 용량"
        }
    }

    var compressionQuality: CGFloat? {
        switch self {
        case .original: return nil
        case .high:     return 0.7
        case .low:      return 0.4
        }
    }

    static let defaultsKey = "imageQualityOption"
}

struct UserSettingsClient: Sendable {
    var imageQuality: @Sendable () -> ImageQualityOption
    var setImageQuality: @Sendable (ImageQualityOption) -> Void
}

extension UserSettingsClient: DependencyKey {
    static var liveValue: UserSettingsClient {
        UserSettingsClient(
            imageQuality: {
                let raw = UserDefaults.standard.string(forKey: ImageQualityOption.defaultsKey) ?? ""
                return ImageQualityOption(rawValue: raw) ?? .original
            },
            setImageQuality: { option in
                UserDefaults.standard.set(option.rawValue, forKey: ImageQualityOption.defaultsKey)
            }
        )
    }

    static var testValue: UserSettingsClient {
        UserSettingsClient(
            imageQuality: { .original },
            setImageQuality: { _ in }
        )
    }
}

extension DependencyValues {
    var userSettings: UserSettingsClient {
        get { self[UserSettingsClient.self] }
        set { self[UserSettingsClient.self] = newValue }
    }
}
