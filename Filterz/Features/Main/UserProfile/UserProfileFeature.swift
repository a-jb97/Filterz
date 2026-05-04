import ComposableArchitecture
import Foundation

struct UserProfile: Equatable, Sendable {
    let userId: String
    let nick: String
    let name: String?
    let introduction: String?
    let profileImagePath: String?
    let hashTags: [String]

    init(dto: UserProfileResponseDTO) {
        userId = dto.userID
        nick = dto.nick
        name = dto.name
        introduction = dto.introduction
        profileImagePath = dto.profileImage
        hashTags = dto.hashTags
    }
}

@Reducer
struct UserProfileFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        let userId: String
        var profile: UserProfile? = nil
        var isLoading: Bool = false
        var errorMessage: String? = nil

        var id: String { userId }
    }

    enum Action: Sendable {
        case onAppear
        case retryTapped
        case profileResponse(Result<UserProfileResponseDTO, any Error>)
        case errorDismissed
    }

    @Dependency(\.userClient) var userClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.profile == nil, !state.isLoading else { return .none }
                return fetchProfile(&state)

            case .retryTapped:
                return fetchProfile(&state, force: true)

            case .profileResponse(.success(let dto)):
                state.isLoading = false
                state.profile = UserProfile(dto: dto)
                return .none

            case .profileResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = displayMessage(for: error)
                return .none

            case .errorDismissed:
                state.errorMessage = nil
                return .none
            }
        }
    }

    private func fetchProfile(_ state: inout State, force: Bool = false) -> Effect<Action> {
        guard force || state.profile == nil else { return .none }
        guard !state.isLoading else { return .none }
        state.isLoading = true
        state.errorMessage = nil
        let userId = state.userId
        return .run { send in
            await send(.profileResponse(Result { try await userClient.userProfile(userId) }))
        }
    }
}

nonisolated private func displayMessage(for error: any Error) -> String {
    (error as? NetworkError)?.errorDescription ?? error.localizedDescription
}
