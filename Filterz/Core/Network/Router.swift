// Router.swift

import Alamofire
import Foundation

enum Router: URLRequestConvertible {

    // MARK: - User
    case join(query: JoinRequestDTO)
    case login(query: LoginRequestDTO)
    case kakaoLogin(query: KakaoLoginRequestDTO)
    case appleLogin(query: AppleLoginRequestDTO)
    case emailValidation(query: EmailValidationRequestDTO)
    case refreshToken(query: RefreshTokenRequestDTO)
    case logout
    case myInfo
    case withdraw
    case getTodayAuthor

    // MARK: - Filter
    case getFilters
    case createFilter
    case getFilter(id: String)
    case editFilter(id: String)
    case deleteFilter(id: String)
    case likeFilter(id: String)
    case getFilterGeo
    case getTodayFilter
    case getHotTrendFilters
    case createFilterComment(filterId: String)
    case deleteFilterComment(filterId: String, commentId: String)

    // MARK: - Post
    case getPosts
    case createPost(query: CreatePostRequestDTO)
    case getPost(id: String)
    case editPost(id: String)
    case deletePost(id: String)
    case likePost(id: String)
    case createPostComment(postId: String)
    case deletePostComment(postId: String, commentId: String)

    // MARK: - Chat
    case getChatRooms
    case createChatRoom(query: CreateChatRoomRequestDTO)
    case getChatMessages(roomId: String)
    case sendMessage(roomId: String, query: SendMessageRequestDTO)
    case sendChatFiles(roomId: String)

    // MARK: - Order & Payment
    case createOrder(filterId: String)
    case getOrders
    case getOrder(orderId: String)
    case validatePayment(query: PaymentValidationRequestDTO)

    // MARK: - Video
    case getVideos
    case getVideo(id: String)
    case getStreamURL(id: String)
    case likeVideo(id: String, query: VideoLikeRequestDTO)

    // MARK: - Common
    case uploadFile
    case getBanners
    case getLogs
    case sendPushNotification(query: PushNotificationRequestDTO)
}

// MARK: - URLRequestConvertible

extension Router {

    private var baseURL: URL {
        URL(string: APIKey.baseURL)!
    }

    private var path: String {
        switch self {
        // User
        case .join:                                         return "/users/join"
        case .login:                                        return "/users/login"
        case .kakaoLogin:                                   return "/users/login/kakao"
        case .appleLogin:                                   return "/users/login/apple"
        case .emailValidation:                              return "/users/validation/email"
        case .refreshToken:                                 return "/auth/refresh"
        case .logout:                                       return "/users/logout"
        case .myInfo:                                       return "/users/me"
        case .withdraw:                                     return "/users/withdraw"
        case .getTodayAuthor:                               return "/users/today-author"
        // Filter
        case .getFilters, .createFilter:                    return "/filters"
        case .getFilter(let id), .editFilter(let id),
             .deleteFilter(let id):                         return "/filters/\(id)"
        case .likeFilter(let id):                           return "/filters/\(id)/like"
        case .getFilterGeo:                                 return "/filters/geo"
        case .getTodayFilter:                               return "/filters/today-filter"
        case .getHotTrendFilters:                           return "/filters/hot-trend"
        case .createFilterComment(let id):                  return "/filters/\(id)/comments"
        case .deleteFilterComment(let fId, let cId):        return "/filters/\(fId)/comments/\(cId)"
        // Post
        case .getPosts, .createPost:                        return "/posts"
        case .getPost(let id), .editPost(let id),
             .deletePost(let id):                           return "/posts/\(id)"
        case .likePost(let id):                             return "/posts/\(id)/like"
        case .createPostComment(let id):                    return "/posts/\(id)/comments"
        case .deletePostComment(let pId, let cId):          return "/posts/\(pId)/comments/\(cId)"
        // Chat
        case .getChatRooms, .createChatRoom:                return "/chats"
        case .getChatMessages(let id),
             .sendMessage(let id, _):                       return "/chats/\(id)"
        case .sendChatFiles(let id):                        return "/chats/\(id)/files"
        // Order & Payment
        case .createOrder(let id):                          return "/orders/\(id)"
        case .getOrders:                                    return "/orders"
        case .getOrder(let id):                             return "/orders/\(id)"
        case .validatePayment:                              return "/payments/validation"
        // Video
        case .getVideos:                                    return "/videos"
        case .getVideo(let id):                             return "/videos/\(id)"
        case .getStreamURL(let id):                         return "/videos/\(id)/stream"
        case .likeVideo(let id, _):                         return "/videos/\(id)/like"
        // Common
        case .uploadFile:                                   return "/files"
        case .getBanners:                                   return "/banners/main"
        case .getLogs:                                      return "/logs"
        case .sendPushNotification:                         return "/notifications"
        }
    }

    private var method: HTTPMethod {
        switch self {
        case .myInfo, .getTodayAuthor, .getFilters, .getFilter, .getFilterGeo, .getTodayFilter, .getHotTrendFilters,
             .getPosts, .getPost,
             .getChatRooms, .getChatMessages,
             .getOrders, .getOrder,
             .getVideos, .getVideo, .getStreamURL,
             .getBanners, .getLogs:
            return .get
        case .editFilter, .editPost:
            return .put
        case .deleteFilter, .deleteFilterComment,
             .deletePost, .deletePostComment,
             .withdraw:
            return .delete
        default:
            return .post
        }
    }

    private var requiresAuth: Bool {
        switch self {
        case .join, .login, .kakaoLogin, .appleLogin, .emailValidation, .refreshToken:
            return false
        default:
            return true
        }
    }

    func asURLRequest() throws -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.method = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(APIKey.apiKey, forHTTPHeaderField: "SeSACKey")
        if requiresAuth {
            request.setValue(APIKey.accessToken, forHTTPHeaderField: "Authorization")
        }

        switch self {
        case .join(let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .login(let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .kakaoLogin(let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .appleLogin(let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .emailValidation(let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .refreshToken(let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .createPost(let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .createChatRoom(let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .sendMessage(_, let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .validatePayment(let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .likeVideo(_, let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .sendPushNotification(let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        default:
            return request
        }
    }
}
