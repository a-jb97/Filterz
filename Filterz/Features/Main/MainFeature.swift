import ComposableArchitecture

@Reducer
struct MainFeature {

    enum Tab: Equatable, CaseIterable {
        case home, market, explore, search, mypage
    }

    @Reducer(state: .equatable)
    enum Path {
        case filterDetail(FilterDetailFeature)
    }

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .home
        var home: HomeFeature.State = .init()
        var feed: FeedFeature.State = .init()
        var upload: UploadFilterFeature.State = .init()
        var path: StackState<Path.State> = .init()
    }

    enum Action: Sendable {
        case tabSelected(Tab)
        case home(HomeFeature.Action)
        case feed(FeedFeature.Action)
        case upload(UploadFilterFeature.Action)
        case path(StackActionOf<Path>)
        case logoutTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case logoutCompleted
        }
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Scope(state: \.feed, action: \.feed) {
            FeedFeature()
        }
        Scope(state: \.upload, action: \.upload) {
            UploadFilterFeature()
        }
        Reduce { state, action in
            switch action {
            case .tabSelected(let tab):
                let returning = tab == .explore && state.selectedTab != .explore
                state.selectedTab = tab
                return returning ? .send(.upload(.reset)) : .none

            case .home(.delegate(.filterTapped(let id))):
                state.path.append(.filterDetail(.init(filterId: id)))
                return .none

            case .home(.delegate(.categoryTapped(let category))):
                state.selectedTab = .market
                return .send(.feed(.categorySelected(category)))

            case .feed(.delegate(.filterTapped(let id))):
                state.path.append(.filterDetail(.init(filterId: id)))
                return .none

            case .path(.element(_, .filterDetail(.delegate(.backTapped)))):
                state.path.removeLast()
                return .none

            case .home, .feed, .upload, .path:
                return .none

            case .logoutTapped:
                return .send(.delegate(.logoutCompleted))

            case .delegate:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
