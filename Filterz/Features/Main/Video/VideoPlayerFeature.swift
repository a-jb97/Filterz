import ComposableArchitecture
import Foundation

@Reducer
struct VideoPlayerFeature {
    @ObservableState
    struct State: Equatable {
        let video: VideoItem
        let stream: VideoStream
        var errorMessage: String? = nil
    }

    enum Action: Sendable {
        case backTapped
        case playbackFailed(String?)
        case errorDismissed
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case backTapped
        }
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .backTapped:
                return .send(.delegate(.backTapped))

            case .playbackFailed(let reason):
                if let reason, !reason.isEmpty {
                    state.errorMessage = "영상을 재생할 수 없습니다.\n\(reason)"
                } else {
                    state.errorMessage = "영상을 재생할 수 없습니다."
                }
                return .none

            case .errorDismissed:
                state.errorMessage = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
