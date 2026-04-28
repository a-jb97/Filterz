import Foundation
import ComposableArchitecture
import KakaoSDKAuth
import KakaoSDKUser

struct KakaoAuthClient: Sendable {
    /// KakaoSDK 로그인 후 access token 반환
    var login: @Sendable () async throws -> String
}

extension KakaoAuthClient: DependencyKey {
    static var liveValue: KakaoAuthClient {
        KakaoAuthClient(
            login: {
                try await withCheckedThrowingContinuation { continuation in
                    DispatchQueue.main.async {
                        let completion: (OAuthToken?, Error?) -> Void = { token, error in
                            if let error {
                                continuation.resume(throwing: error)
                                return
                            }
                            guard let accessToken = token?.accessToken else {
                                continuation.resume(throwing: AuthError.unknown)
                                return
                            }
                            continuation.resume(returning: accessToken)
                        }

                        if UserApi.isKakaoTalkLoginAvailable() {
                            UserApi.shared.loginWithKakaoTalk(completion: completion)
                        } else {
                            UserApi.shared.loginWithKakaoAccount(completion: completion)
                        }
                    }
                }
            }
        )
    }

    static var testValue: KakaoAuthClient {
        KakaoAuthClient(login: { "kakao-test-token" })
    }
}

extension DependencyValues {
    var kakaoAuthClient: KakaoAuthClient {
        get { self[KakaoAuthClient.self] }
        set { self[KakaoAuthClient.self] = newValue }
    }
}
