import Foundation

enum NetworkError: Error, LocalizedError {
    case unauthorized
    case notFound
    case serverError(Int)
    case decodingFailed
    case noInternet
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized:         return "인증이 만료되었습니다. 다시 로그인해주세요."
        case .notFound:             return "요청한 리소스를 찾을 수 없습니다."
        case .serverError(let c):   return "서버 오류가 발생했습니다. (코드: \(c))"
        case .decodingFailed:       return "데이터 처리 중 오류가 발생했습니다."
        case .noInternet:           return "인터넷 연결을 확인해주세요."
        case .unknown(let e):       return e.localizedDescription
        }
    }
}
