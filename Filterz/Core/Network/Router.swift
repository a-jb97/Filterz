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
    case editMyProfile(query: EditMyProfileRequestDTO)
    case userProfile(userId: String)
    case getTodayAuthor
    case searchUsers(nick: String?)

    // MARK: - Filter
    case getFilters(next: String? = nil, category: String? = nil)
    case getUserFilters(userId: String, query: UserFilterListRequestDTO)
    case getLikedFilters(query: LikedFilterListRequestDTO)
    case createFilter(query: CreateFilterRequestDTO)
    case getFilter(id: String)
    case editFilter(id: String, query: CreateFilterRequestDTO)
    case deleteFilter(id: String)
    case likeFilter(id: String, query: FilterLikeRequestDTO)
    case getTodayFilter
    case getHotTrendFilters
    case createFilterComment(filterId: String, query: FilterCommentRequestDTO)
    case editFilterComment(filterId: String, commentId: String, query: FilterCommentRequestDTO)
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
    case getChatMessages(roomId: String, next: String? = nil)
    case sendMessage(roomId: String, query: SendMessageRequestDTO)
    case sendChatFiles(roomId: String)

    // MARK: - Order & Payment
    case createOrder(query: OrderCreateRequestDTO)
    case getOrders
    case getOrder(orderCode: String)
    case validatePayment(query: PaymentValidationRequestDTO)

    // MARK: - Video
    case getVideos(query: VideoListRequestDTO)
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
        case .myInfo, .editMyProfile:                       return "/users/me/profile"
        case .userProfile(let userId):                      return "/users/\(userId)/profile"
        case .getTodayAuthor:                               return "/users/today-author"
        case .searchUsers:                                  return "/users/search"
        // Filter
        case .getFilters(_, _), .createFilter:                  return "/filters"
        case .getUserFilters(let userId, _):                return "/filters/users/\(userId)"
        case .getLikedFilters:                              return "/filters/likes/me"
        case .getFilter(let id), .editFilter(let id, _),
             .deleteFilter(let id):                         return "/filters/\(id)"
        case .likeFilter(let id, _):                        return "/filters/\(id)/like"
        case .getTodayFilter:                               return "/filters/today-filter"
        case .getHotTrendFilters:                           return "/filters/hot-trend"
        case .createFilterComment(let id, _):               return "/filters/\(id)/comments"
        case .editFilterComment(let fId, let cId, _),
             .deleteFilterComment(let fId, let cId):        return "/filters/\(fId)/comments/\(cId)"
        // Post
        case .getPosts, .createPost:                        return "/posts"
        case .getPost(let id), .editPost(let id),
             .deletePost(let id):                           return "/posts/\(id)"
        case .likePost(let id):                             return "/posts/\(id)/like"
        case .createPostComment(let id):                    return "/posts/\(id)/comments"
        case .deletePostComment(let pId, let cId):          return "/posts/\(pId)/comments/\(cId)"
        // Chat
        case .getChatRooms, .createChatRoom:                return "/chats"
        case .getChatMessages(let id, _),
             .sendMessage(let id, _):                       return "/chats/\(id)"
        case .sendChatFiles(let id):                        return "/chats/\(id)/files"
        // Order & Payment
        case .createOrder:                                  return "/orders"
        case .getOrders:                                    return "/orders"
        case .getOrder(let code):                           return "/payments/\(code)"
        case .validatePayment:                              return "/payments/validation"
        // Video
        case .getVideos:                                    return "/videos"
        case .getVideo(let id):                             return "/videos/\(id)"
        case .getStreamURL(let id):                         return "/videos/\(id)/stream"
        case .likeVideo(let id, _):                         return "/videos/\(id)/like"
        // Common
        case .uploadFile:                                   return "/filters/files"
        case .getBanners:                                   return "/banners/main"
        case .getLogs:                                      return "/logs"
        case .sendPushNotification:                         return "/notifications/push"
        }
    }

    private var method: HTTPMethod {
        switch self {
        case .myInfo, .userProfile, .getTodayAuthor, .searchUsers, .getFilters(_, _), .getUserFilters, .getLikedFilters, .getFilter, .getTodayFilter, .getHotTrendFilters,
             .getPosts, .getPost,
             .getChatRooms, .getChatMessages,
             .getOrders, .getOrder,
             .getVideos, .getVideo, .getStreamURL,
             .getBanners, .getLogs,
             .refreshToken:
            return .get
        case .editMyProfile, .editFilter, .editFilterComment, .editPost:
            return .put
        case .deleteFilter, .deleteFilterComment,
             .deletePost, .deletePostComment:
            return .delete
        default:
            return .post
        }
    }

    private var requiresAuth: Bool {
        switch self {
        case .join, .login, .kakaoLogin, .appleLogin, .emailValidation:
            return false
        default:
            return true
        }
    }

    func asURLRequest() throws -> URLRequest {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if case .getFilters(let next, let category) = self {
            var items: [URLQueryItem] = []
            if let next     { items.append(URLQueryItem(name: "next",     value: next)) }
            if let category { items.append(URLQueryItem(name: "category", value: category)) }
            if !items.isEmpty { urlComponents.queryItems = items }
        }
        if case .getUserFilters(_, let query) = self {
            var items: [URLQueryItem] = []
            if let next = query.next { items.append(URLQueryItem(name: "next", value: next)) }
            if let limit = query.limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
            if let category = query.category { items.append(URLQueryItem(name: "category", value: category)) }
            if !items.isEmpty { urlComponents.queryItems = items }
        }
        if case .getLikedFilters(let query) = self {
            var items: [URLQueryItem] = []
            if let next = query.next { items.append(URLQueryItem(name: "next", value: next)) }
            if let limit = query.limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
            if let category = query.category { items.append(URLQueryItem(name: "category", value: category)) }
            if !items.isEmpty { urlComponents.queryItems = items }
        }
        if case .getVideos(let query) = self {
            var items: [URLQueryItem] = []
            if let next = query.next { items.append(URLQueryItem(name: "next", value: next)) }
            if let limit = query.limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
            if !items.isEmpty { urlComponents.queryItems = items }
        }
        if case .searchUsers(let nick) = self, let nick {
            urlComponents.queryItems = [URLQueryItem(name: "nick", value: nick)]
        }
        if case .getChatMessages(_, let next) = self, let next {
            urlComponents.queryItems = [URLQueryItem(name: "next", value: next)]
        }
        let url = urlComponents.url!
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
            request.setValue(query.refreshToken, forHTTPHeaderField: "RefreshToken")
            return request
        case .editMyProfile(let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .createFilter(let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .editFilter(_, let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .createFilterComment(_, let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .editFilterComment(_, _, let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .createPost(let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .createChatRoom(let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .sendMessage(_, let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .createOrder(let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .validatePayment(let query):
            return try JSONParameterEncoder.default.encode(query, into: request)
        case .likeFilter(_, let query):
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
