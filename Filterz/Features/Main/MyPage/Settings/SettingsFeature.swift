import ComposableArchitecture

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        var selectedQuality: ImageQualityOption = .original
        var isAISummaryEnabled: Bool = true
    }

    enum Action: Sendable {
        case onAppear
        case qualitySelected(ImageQualityOption)
        case aiSummaryEnabledChanged(Bool)
    }

    @Dependency(\.userSettings) var userSettings

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.selectedQuality = userSettings.imageQuality()
                state.isAISummaryEnabled = userSettings.isAISummaryEnabled()
                return .none

            case let .qualitySelected(option):
                state.selectedQuality = option
                userSettings.setImageQuality(option)
                return .none

            case let .aiSummaryEnabledChanged(isEnabled):
                state.isAISummaryEnabled = isEnabled
                userSettings.setAISummaryEnabled(isEnabled)
                return .none
            }
        }
    }
}
