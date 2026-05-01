// NetworkManager.swift

import Alamofire
import Foundation
import os

// MARK: - AuthInterceptor

private final class AuthInterceptor: RequestInterceptor, @unchecked Sendable {
    private let refreshSession = Session()
    private let state = OSAllocatedUnfairLock<(isRefreshing: Bool, pending: [(RetryResult) -> Void])>(
        initialState: (isRefreshing: false, pending: [])
    )

    func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        let statusCode = (request.task?.response as? HTTPURLResponse)?.statusCode

        guard
            let statusCode,
            (statusCode == 401 || statusCode == 418 || statusCode == 419),
            request.retryCount == 0
        else {
            completion(.doNotRetry)
            return
        }

        let shouldReturn = state.withLock { s -> Bool in
            if s.isRefreshing {
                s.pending.append(completion)
                return true
            } else {
                s.isRefreshing = true
                return false
            }
        }
        if shouldReturn { return }

        Task {
            let router = Router.refreshToken(
                query: RefreshTokenRequestDTO(refreshToken: APIKey.refreshToken)
            )
            let result = await refreshSession
                .request(router)
                .validate(statusCode: 200..<300)
                .serializingData()
                .response

            let pending = state.withLock { s -> [(RetryResult) -> Void] in
                let p = s.pending
                s.pending.removeAll()
                s.isRefreshing = false
                return p
            }

            switch result.result {
            case .success(let data):
                do {
                    let dto = try JSONDecoder().decode(RefreshTokenResponseDTO.self, from: data)
                    APIKey.accessToken = dto.accessToken
                    APIKey.refreshToken = dto.refreshToken
                    KeychainHelper.save(dto.accessToken, forKey: "accessToken")
                    KeychainHelper.save(dto.refreshToken, forKey: "refreshToken")
                    completion(.retry)
                    pending.forEach { $0(.retry) }
                } catch {
                    completion(.doNotRetryWithError(NetworkError.unauthorized))
                    pending.forEach { $0(.doNotRetryWithError(NetworkError.unauthorized)) }
                }
            case .failure:
                KeychainHelper.delete(forKey: "accessToken")
                KeychainHelper.delete(forKey: "refreshToken")
                KeychainHelper.delete(forKey: "userId")
                APIKey.accessToken = ""
                APIKey.refreshToken = ""
                completion(.doNotRetryWithError(NetworkError.unauthorized))
                pending.forEach { $0(.doNotRetryWithError(NetworkError.unauthorized)) }
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
            do { return try decoder.decode(T.self, from: data) }
            catch { throw NetworkError.decodingFailed }
        case .failure(let error):
            throw mapError(error, statusCode: response.response?.statusCode, data: response.data)
        }
    }

    func requestRaw(_ router: Router) async throws -> Data {
        let response = await session
            .request(router)
            .validate(statusCode: 200..<300)
            .serializingData()
            .response

        switch response.result {
        case .success(let data): return data
        case .failure(let error):
            throw mapError(error, statusCode: response.response?.statusCode, data: response.data)
        }
    }

    func uploadFiles<T: Decodable>(_ router: Router, images: [Data]) async throws -> T {
        var urlRequest = try router.asURLRequest()

        let multipart = MultipartFormData()
        for (i, data) in images.enumerated() {
            multipart.append(data, withName: "files",
                             fileName: "image\(i).jpg",
                             mimeType: "image/jpeg")
        }

        let encoded = try multipart.encode()
        urlRequest.setValue(multipart.contentType, forHTTPHeaderField: "Content-Type")

        let response = await session
            .upload(encoded, with: urlRequest)
            .validate(statusCode: 200..<300)
            .serializingData()
            .response

        switch response.result {
        case .success(let data):
            do { return try decoder.decode(T.self, from: data) }
            catch { throw NetworkError.decodingFailed }
        case .failure(let error):
            throw mapError(error, statusCode: response.response?.statusCode, data: response.data)
        }
    }

    func requestVoid(_ router: Router) async throws {
        let response = await session
            .request(router)
            .validate(statusCode: 200..<300)
            .serializingData()
            .response

        if let error = response.error {
            throw mapError(error, statusCode: response.response?.statusCode, data: response.data)
        }
    }

    private func mapError(_ error: AFError, statusCode: Int?, data: Data?) -> NetworkError {
        if let data,
           let body = try? decoder.decode(ServerErrorDTO.self, from: data) {
            return .serverMessage(body.message)
        }
        if let code = statusCode {
            switch code {
            case 401, 418, 419: return .unauthorized
            case 404:           return .notFound
            default:            return .serverError(code)
            }
        }
        if case .sessionTaskFailed(let urlError as URLError) = error,
           urlError.code == .notConnectedToInternet {
            return .noInternet
        }
        return .unknown(error)
    }
}

private struct ServerErrorDTO: Decodable {
    let message: String
}
