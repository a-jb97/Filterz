import ComposableArchitecture
import Foundation

@Reducer
struct VideoListFeature {
    @ObservableState
    struct State: Equatable {
        var items: [VideoItem] = []
        var nextCursor: String? = nil
        var hasMore: Bool = true
        var isLoading: Bool = false
        var loadingStreamVideoId: String? = nil
        var errorMessage: String? = nil
    }

    enum Action: Sendable {
        case onAppear
        case backTapped
        case loadMore
        case response(Result<VideoListResponseDTO, any Error>, append: Bool)
        case videoTapped(id: String)
        case streamURLResponse(Result<StreamUrlResponseDTO, any Error>, video: VideoItem)
        case likeButtonTapped(id: String)
        case likeResponse(Result<Void, any Error>, id: String, previous: VideoItem)
        case errorDismissed
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case backTapped
            case playVideoRequested(video: VideoItem, stream: VideoStream)
        }
    }

    @Dependency(\.videoClient) var videoClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return state.items.isEmpty ? fetchVideos(&state, append: false) : .none

            case .backTapped:
                return .send(.delegate(.backTapped))

            case .loadMore:
                return fetchVideos(&state, append: true)

            case .response(.success(let dto), let append):
                state.isLoading = false
                let items = dto.data.map(VideoItem.init(dto:))
                state.items = append ? state.items + items : items
                state.nextCursor = dto.nextCursor
                state.hasMore = dto.nextCursor != nil && dto.nextCursor != "0"
                return .none

            case .response(.failure(let error), _):
                state.isLoading = false
                state.errorMessage = displayMessage(for: error)
                return .none

            case .videoTapped(let id):
                guard state.loadingStreamVideoId == nil,
                      let video = state.items.first(where: { $0.id == id }) else {
                    return .none
                }
                state.loadingStreamVideoId = id
                state.errorMessage = nil
                return .run { [videoClient] send in
                    await send(.streamURLResponse(
                        Result { try await videoClient.getStreamURL(id) },
                        video: video
                    ))
                }

            case .streamURLResponse(.success(let dto), let video):
                state.loadingStreamVideoId = nil
                return .send(.delegate(.playVideoRequested(video: video, stream: VideoStream(dto: dto))))

            case .streamURLResponse(.failure(let error), _):
                state.loadingStreamVideoId = nil
                state.errorMessage = displayMessage(for: error)
                return .none

            case .likeButtonTapped(let id):
                guard let index = state.items.firstIndex(where: { $0.id == id }) else {
                    return .none
                }
                let previous = state.items[index]
                let targetStatus = !previous.isLiked
                state.items[index] = previous.updatingLike(isLiked: targetStatus)
                state.errorMessage = nil
                return .run { [videoClient] send in
                    do {
                        try await videoClient.likeVideo(id, targetStatus)
                        await send(.likeResponse(.success(()), id: id, previous: previous))
                    } catch {
                        await send(.likeResponse(.failure(error), id: id, previous: previous))
                    }
                }

            case .likeResponse(.success, _, _):
                return .none

            case .likeResponse(.failure(let error), let id, let previous):
                if let index = state.items.firstIndex(where: { $0.id == id }) {
                    state.items[index] = previous
                }
                state.errorMessage = displayMessage(for: error)
                return .none

            case .errorDismissed:
                state.errorMessage = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func fetchVideos(_ state: inout State, append: Bool) -> Effect<Action> {
        guard !state.isLoading else { return .none }
        guard !append || state.hasMore else { return .none }
        state.isLoading = true
        if !append {
            state.items = []
            state.nextCursor = nil
            state.hasMore = true
        }
        state.errorMessage = nil
        let query = VideoListRequestDTO(next: append ? state.nextCursor : nil, limit: 5)
        return .run { [videoClient] send in
            await send(.response(
                Result { try await videoClient.getVideos(query) },
                append: append
            ))
        }
    }
}

nonisolated private func displayMessage(for error: any Error) -> String {
    (error as? NetworkError)?.errorDescription ?? error.localizedDescription
}
