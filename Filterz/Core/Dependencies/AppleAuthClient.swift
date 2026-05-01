import Foundation
import AuthenticationServices
import ComposableArchitecture
import UIKit

struct AppleCredential: Equatable, Sendable {
    let identityToken: String
    let authorizationCode: String
    let fullName: PersonNameComponents?

    static func == (lhs: AppleCredential, rhs: AppleCredential) -> Bool {
        lhs.identityToken == rhs.identityToken && lhs.authorizationCode == rhs.authorizationCode
    }
}

struct AppleAuthClient: Sendable {
    var login: @Sendable () async throws -> AppleCredential
}

extension AppleAuthClient: DependencyKey {
    static var liveValue: AppleAuthClient {
        AppleAuthClient(
            login: {
                try await withCheckedThrowingContinuation { continuation in
                    // ASAuthorizationController은 메인 스레드에서 실행해야 함
                    Task { @MainActor in
                        let provider = ASAuthorizationAppleIDProvider()
                        let request = provider.createRequest()
                        request.requestedScopes = [.fullName, .email]

                        let delegate = AppleSignInDelegate(continuation: continuation)
                        let controller = ASAuthorizationController(authorizationRequests: [request])
                        controller.delegate = delegate
                        controller.presentationContextProvider = delegate
                        controller.performRequests()
                        // controller가 delegate를 weak으로 잡으므로 controller에 강한 참조로 묶어둠
                        objc_setAssociatedObject(controller, &AssociatedKeys.delegate, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    }
                }
            }
        )
    }

    static var testValue: AppleAuthClient {
        AppleAuthClient(
            login: {
                AppleCredential(
                    identityToken: "apple-test-identity",
                    authorizationCode: "apple-test-code",
                    fullName: nil
                )
            }
        )
    }
}

extension DependencyValues {
    var appleAuthClient: AppleAuthClient {
        get { self[AppleAuthClient.self] }
        set { self[AppleAuthClient.self] = newValue }
    }
}

// MARK: - Associated Key

private enum AssociatedKeys {
    nonisolated(unsafe) static var delegate = 0
}

// MARK: - ASAuthorizationController Delegate Bridge

private final class AppleSignInDelegate: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding,
    @unchecked Sendable {
    private var continuation: CheckedContinuation<AppleCredential, Error>?

    init(continuation: CheckedContinuation<AppleCredential, Error>) {
        self.continuation = continuation
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
            let identityData = cred.identityToken,
            let codeData = cred.authorizationCode,
            let identityToken = String(data: identityData, encoding: .utf8),
            let authCode = String(data: codeData, encoding: .utf8)
        else {
            continuation?.resume(throwing: AuthError.unknown)
            continuation = nil
            return
        }
        continuation?.resume(returning: AppleCredential(
            identityToken: identityToken,
            authorizationCode: authCode,
            fullName: cred.fullName
        ))
        continuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
