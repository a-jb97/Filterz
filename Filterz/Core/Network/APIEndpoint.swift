import Foundation

enum SocialProvider: String, Sendable {
    case kakao, apple
}

enum APIEndpoint {
    case emailLogin(email: String, password: String)
    case signUp(email: String, password: String, nickname: String)
    case checkEmail(email: String)
    case checkNickname(nickname: String)
    case socialLogin(provider: SocialProvider, token: String)
    case refreshToken(token: String)
    case logout

    private var baseURL: String { "https://api.filterz.io/v1" }

    var urlRequest: URLRequest {
        switch self {
        case .emailLogin(let email, let password):
            return post("/auth/login", body: ["email": email, "password": password])
        case .signUp(let email, let password, let nickname):
            return post("/auth/signup", body: ["email": email, "password": password, "nickname": nickname])
        case .checkEmail(let email):
            return post("/auth/check-email", body: ["email": email])
        case .checkNickname(let nickname):
            return post("/auth/check-nickname", body: ["nickname": nickname])
        case .socialLogin(let provider, let token):
            return post("/auth/social", body: ["provider": provider.rawValue, "token": token])
        case .refreshToken(let token):
            return post("/auth/refresh", body: ["refreshToken": token])
        case .logout:
            return post("/auth/logout", body: [:])
        }
    }

    private func post(_ path: String, body: [String: Any]) -> URLRequest {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }
}
