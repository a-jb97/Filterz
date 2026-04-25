import ComposableArchitecture

@Reducer
struct MainFeature {
    @ObservableState
    struct State: Equatable {}

    enum Action: Sendable {
        case logoutTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case logoutCompleted
        }
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .logoutTapped:
                return .send(.delegate(.logoutCompleted))
            case .delegate:
                return .none
            }
        }
    }
}
