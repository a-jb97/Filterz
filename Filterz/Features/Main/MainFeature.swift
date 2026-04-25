import ComposableArchitecture

@Reducer
struct MainFeature {

    enum Tab: Equatable, CaseIterable {
        case home, market, explore, search, mypage
    }

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .home
        var home: HomeFeature.State = .init()
    }

    enum Action: Sendable {
        case tabSelected(Tab)
        case home(HomeFeature.Action)
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
        Reduce { state, action in
            switch action {
            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none
            case .home:
                return .none
            case .logoutTapped:
                return .send(.delegate(.logoutCompleted))
            case .delegate:
                return .none
            }
        }
    }
}
