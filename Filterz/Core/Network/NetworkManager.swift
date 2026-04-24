// NetworkManager.swift

import Alamofire
import Foundation

// MARK: - AuthInterceptor

private final class AuthInterceptor: RequestInterceptor, @unchecked Sendable {
    private let refreshSession = Session()

    func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        guard
            let response = request.task?.response as? HTTPURLResponse,
            response.statusCode == 401,
            request.retryCount == 0
        else {
            completion(.doNotRetry)
            return
        }

        Task {
            let router = Router.refreshToken(
                query: RefreshTokenRequestDTO(refreshToken: APIKey.refreshToken)
            )
            let result = await refreshSession
                .request(router)
                .validate(statusCode: 200..<300)
                .serializingData()
                .response

            switch result.result {
            case .success(let data):
                do {
                    let dto = try JSONDecoder().decode(RefreshTokenResponseDTO.self, from: data)
                    APIKey.accessToken = dto.accessToken
                    completion(.retry)
                } catch {
                    completion(.doNotRetryWithError(NetworkError.unauthorized))
                }
            case .failure:
                completion(.doNotRetryWithError(NetworkError.unauthorized))
            }
        }
    }
}

// MARK: - NetworkManager

final class NetworkManager: @unchecked Sendable {
    static let shared = NetworkManager()

    private let session: Session
    private let decoder = JSONDecoder()

    private init() {
        session = Session(interceptor: AuthInterceptor())
    }

    func request<T: Decodable>(_ router: Router) async throws -> T {
        let response = await session
            .request(router)
            .validate(statusCode: 200..<300)
            .serializingData()
            .response

        switch response.result {
        case .success(let data):
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingFailed
            }
        case .failure(let error):
            throw mapError(error, statusCode: response.response?.statusCode)
        }
    }

    func requestVoid(_ router: Router) async throws {
        let response = await session
            .request(router)
            .validate(statusCode: 200..<300)
            .serializingData()
            .response

        if let error = response.error {
            throw mapError(error, statusCode: response.response?.statusCode)
        }
    }

    private func mapError(_ error: AFError, statusCode: Int?) -> NetworkError {
        if let code = statusCode {
            switch code {
            case 401: return .unauthorized
            case 404: return .notFound
            default:  return .serverError(code)
            }
        }
        if case .sessionTaskFailed(let urlError as URLError) = error,
           urlError.code == .notConnectedToInternet {
            return .noInternet
        }
        return .unknown(error)
    }
}
