// FilterMakerFeature.swift

import ComposableArchitecture
import Foundation

@Reducer
struct FilterMakerFeature {
    enum Source: Equatable, Sendable {
        case local(Data)
        case remote(String)
    }

    @ObservableState
    struct State: Equatable {
        var source: Source
        var sourceImageData: Data?
        var values: FilterAdjustmentValues
        var selectedAdjustment: FilterAdjustmentKey = .saturation
        var undoStack: [FilterAdjustmentValues] = []
        var redoStack: [FilterAdjustmentValues] = []
        var editingStartValues: FilterAdjustmentValues?
        var isShowingOriginal: Bool = false
        var errorMessage: String?

        init(source: Source, values: FilterAdjustmentValues = .init()) {
            self.source = source
            self.values = values.clamped()
            if case .local(let data) = source {
                sourceImageData = data
            }
        }
    }

    enum Action: Sendable {
        case onAppear
        case remoteImageLoaded(Result<Data, Error>)
        case adjustmentSelected(FilterAdjustmentKey)
        case sliderEditingStarted
        case sliderChanged(Float)
        case sliderEditingEnded
        case undoTapped
        case redoTapped
        case originalPressedChanged(Bool)
        case saveTapped
        case backTapped
        case errorDismissed
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case saved(FilterAdjustmentValues)
            case backTapped
        }
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                switch state.source {
                case .local:
                    return .none
                case .remote(let path):
                    guard state.sourceImageData == nil else {
                        return .none
                    }
                    return .run { send in
                        do {
                            let data = try await loadRemoteImageData(path: path)
                            await send(.remoteImageLoaded(.success(data)))
                        } catch {
                            await send(.remoteImageLoaded(.failure(error)))
                        }
                    }
                }

            case .remoteImageLoaded(.success(let data)):
                state.sourceImageData = data
                return .none

            case .remoteImageLoaded(.failure(let error)):
                state.errorMessage = error.localizedDescription
                return .none

            case .adjustmentSelected(let key):
                state.selectedAdjustment = key
                return .none

            case .sliderEditingStarted:
                if state.editingStartValues == nil {
                    state.editingStartValues = state.values
                }
                return .none

            case .sliderChanged(let value):
                state.values[state.selectedAdjustment] = value
                return .none

            case .sliderEditingEnded:
                guard let start = state.editingStartValues else { return .none }
                state.editingStartValues = nil
                guard start != state.values else { return .none }
                state.undoStack.append(start)
                state.redoStack.removeAll()
                return .none

            case .undoTapped:
                guard let previous = state.undoStack.popLast() else { return .none }
                state.redoStack.append(state.values)
                state.values = previous
                return .none

            case .redoTapped:
                guard let next = state.redoStack.popLast() else { return .none }
                state.undoStack.append(state.values)
                state.values = next
                return .none

            case .originalPressedChanged(let isPressed):
                state.isShowingOriginal = isPressed
                return .none

            case .saveTapped:
                return .send(.delegate(.saved(state.values.clamped())))

            case .backTapped:
                return .send(.delegate(.backTapped))

            case .errorDismissed:
                state.errorMessage = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

private func loadRemoteImageData(path: String) async throws -> Data {
    guard let url = URL(string: APIKey.baseURL + path) else {
        throw URLError(.badURL)
    }
    var request = URLRequest(url: url)
    request.setValue(APIKey.apiKey, forHTTPHeaderField: "SeSACKey")
    request.setValue(APIKey.accessToken, forHTTPHeaderField: "Authorization")
    let (data, _) = try await URLSession.shared.data(for: request)
    return data
}
