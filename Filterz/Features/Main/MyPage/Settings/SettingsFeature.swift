import ComposableArchitecture

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        var selectedQuality: ImageQualityOption = .original
    }

    enum Action: Sendable {
        case onAppear
        case qualitySelected(ImageQualityOption)
    }

    @Dependency(\.userSettings) var userSettings

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.selectedQuality = userSettings.imageQuality()
                return .none

            case let .qualitySelected(option):
                state.selectedQuality = option
                userSettings.setImageQuality(option)
                return .none
            }
        }
    }
}

