import Foundation

protocol NetworkClientProtocol: Sendable {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
}

struct NetworkClient: NetworkClientProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: endpoint.urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.unknown(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200..<300:
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingFailed
            }
        case 401: throw NetworkError.unauthorized
        case 404: throw NetworkError.notFound
        default:  throw NetworkError.serverError(http.statusCode)
        }
    }
}
