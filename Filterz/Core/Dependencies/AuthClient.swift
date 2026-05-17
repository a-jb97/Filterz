import Foundation
import ComposableArchitecture

// MARK: - Models

struct AuthToken: Equatable, Sendable, Codable {
    let accessToken: String
    let refreshToken: String
    let userId: String
}

enum AuthError: Error, Equatable, LocalizedError {
    case invalidCredentials
    case emailAlreadyExists
    case nicknameAlreadyExists
    case networkError(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:    return "이메일 또는 비밀번호가 올바르지 않습니다."
        case .emailAlreadyExists:    return "이미 사용 중인 이메일입니다."
        case .nicknameAlreadyExists: return "이미 사용 중인 닉네임입니다."
        case .networkError(let msg): return msg
        case .unknown:               return "알 수 없는 오류가 발생했습니다."
        }
    }
}

// MARK: - AuthClient

struct AuthClient: Sendable {
    var emailLogin: @Sendable (String, String) async throws -> AuthToken
    var signUp: @Sendable (String, String, String) async throws -> AuthToken
    var checkEmailDuplicate: @Sendable (String) async throws -> Bool
    var checkNicknameDuplicate: @Sendable (String) async throws -> Bool
    var socialLogin: @Sendable (SocialProvider, String) async throws -> AuthToken
    var checkSession: @Sendable () async -> Bool
    var refreshToken: @Sendable () async throws -> AuthToken
    var logout: @Sendable () async throws -> Void
}

// MARK: - DependencyKey

extension AuthClient: DependencyKey {
    static var liveValue: AuthClient {
        let manager = NetworkManager.shared
        return AuthClient(
            emailLogin: { email, password in
                do {
                    let deviceToken = PushNotificationBridge.fcmToken
                    let dto: LoginResponseDTO = try await manager.request(
                        .login(query: LoginRequestDTO(email: email, password: password, deviceToken: deviceToken))
                    )
                    APIKey.accessToken = dto.accessToken
                    APIKey.refreshToken = dto.refreshToken
                    KeychainHelper.save(dto.accessToken, forKey: "accessToken")
                    KeychainHelper.save(dto.refreshToken, forKey: "refreshToken")
                    KeychainHelper.save(dto.userID, forKey: "userId")
                    return AuthToken(accessToken: dto.accessToken, refreshToken: dto.refreshToken, userId: dto.userID)
                } catch NetworkError.unauthorized {
                    throw AuthError.invalidCredentials
                } catch let e as NetworkError {
                    throw AuthError.networkError(e.localizedDescription)
                }
            },
            signUp: { email, password, nickname in
                do {
                    let deviceToken = PushNotificationBridge.fcmToken
                    let dto: LoginResponseDTO = try await manager.request(
                        .join(query: JoinRequestDTO(email: email, password: password, nick: nickname, name: nil, introduction: nil, deviceToken: deviceToken))
                    )
                    APIKey.accessToken = dto.accessToken
                    APIKey.refreshToken = dto.refreshToken
                    KeychainHelper.save(dto.accessToken, forKey: "accessToken")
                    KeychainHelper.save(dto.refreshToken, forKey: "refreshToken")
                    KeychainHelper.save(dto.userID, forKey: "userId")
                    return AuthToken(accessToken: dto.accessToken, refreshToken: dto.refreshToken, userId: dto.userID)
                } catch NetworkError.serverError(409) {
                    throw AuthError.emailAlreadyExists
                } catch let e as NetworkError {
                    throw AuthError.networkError(e.localizedDescription)
                }
            },
            checkEmailDuplicate: { email in
                do {
                    try await manager.requestVoid(
                        .emailValidation(query: EmailValidationRequestDTO(email: email))
                    )
                    return true
                } catch NetworkError.serverError(409) {
                    return false
                } catch NetworkError.noInternet {
                    throw AuthError.networkError("인터넷 연결을 확인해주세요.")
                } catch let e as NetworkError {
                    throw AuthError.networkError(e.localizedDescription)
                }
            },
            checkNicknameDuplicate: { _ in
                // 서버에 별도의 닉네임 중복 확인 API가 없음 — 회원가입 시 서버에서 검증됨
                return true
            },
            socialLogin: { provider, token in
                do {
                    let dto: LoginResponseDTO
                    let deviceToken = PushNotificationBridge.fcmToken
                    switch provider {
                    case .kakao:
                        dto = try await manager.request(
                            .kakaoLogin(query: KakaoLoginRequestDTO(oauthToken: token, deviceToken: deviceToken))
                        )
                    case .apple:
                        dto = try await manager.request(
                            .appleLogin(query: AppleLoginRequestDTO(idToken: token, deviceToken: deviceToken))
                        )
                    }
                    APIKey.accessToken = dto.accessToken
                    APIKey.refreshToken = dto.refreshToken
                    KeychainHelper.save(dto.accessToken, forKey: "accessToken")
                    KeychainHelper.save(dto.refreshToken, forKey: "refreshToken")
                    KeychainHelper.save(dto.userID, forKey: "userId")
                    return AuthToken(accessToken: dto.accessToken, refreshToken: dto.refreshToken, userId: dto.userID)
                } catch NetworkError.unauthorized {
                    throw AuthError.invalidCredentials
                } catch let e as NetworkError {
                    throw AuthError.networkError(e.localizedDescription)
                }
            },
            checkSession: {
                guard let access = KeychainHelper.load(forKey: "accessToken"),
                      let refresh = KeychainHelper.load(forKey: "refreshToken"),
                      !access.isEmpty else { return false }
                APIKey.accessToken = access
                APIKey.refreshToken = refresh
                return true
            },
            refreshToken: {
                let dto: RefreshTokenResponseDTO = try await manager.request(
                    .refreshToken(query: RefreshTokenRequestDTO(refreshToken: APIKey.refreshToken))
                )
                APIKey.accessToken = dto.accessToken
                APIKey.refreshToken = dto.refreshToken
                KeychainHelper.save(dto.accessToken, forKey: "accessToken")
                KeychainHelper.save(dto.refreshToken, forKey: "refreshToken")
                let userId = KeychainHelper.load(forKey: "userId") ?? ""
                return AuthToken(accessToken: dto.accessToken, refreshToken: dto.refreshToken, userId: userId)
            },
            logout: {
                try await manager.requestVoid(.logout)
                APIKey.accessToken = ""
                APIKey.refreshToken = ""
                KeychainHelper.delete(forKey: "accessToken")
                KeychainHelper.delete(forKey: "refreshToken")
                KeychainHelper.delete(forKey: "userId")
            }
        )
    }

    static var testValue: AuthClient {
        AuthClient(
            emailLogin: { _, _ in
                AuthToken(accessToken: "test-access", refreshToken: "test-refresh", userId: "test-user")
            },
            signUp: { _, _, _ in
                AuthToken(accessToken: "test-access", refreshToken: "test-refresh", userId: "test-user")
            },
            checkEmailDuplicate: { _ in true },
            checkNicknameDuplicate: { _ in true },
            socialLogin: { _, _ in
                AuthToken(accessToken: "test-access", refreshToken: "test-refresh", userId: "test-user")
            },
            checkSession: { false },
            refreshToken: {
                AuthToken(accessToken: "test-access", refreshToken: "test-refresh", userId: "test-user")
            },
            logout: { }
        )
    }
}

extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}
