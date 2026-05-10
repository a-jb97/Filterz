import ComposableArchitecture
import Foundation

@Reducer
struct CameraFeature {
    @ObservableState
    struct State: Equatable {
        var permissionStatus: CameraPermissionStatus = .notDetermined
        var session: CameraSession?
        var position: CameraPosition = .back
        var flashMode: CameraFlashMode = .off
        var selectedZoomOption: CameraZoomOption = .one
        var supportedZoomOptions: [CameraZoomOption] = [.one]
        var deviceOrientation: CameraDeviceOrientation = .portrait
        var isCapturing = false
        var isWritingMetadata = false
        var capturedPhotoData: Data?
        var activeCaptureID: UUID?
        var errorMessage: String?
        var supportsFlash = false
    }

    enum Action: Sendable {
        case onAppear
        case onDisappear
        case deviceOrientationChanged(CameraDeviceOrientation)
        case permissionResolved(Bool)
        case sessionPrepared(Result<CameraSession, CameraClientError>)
        case startSession
        case closeTapped
        case captureTapped
        case photoCaptured(UUID, Result<Data, CameraClientError>)
        case photoMetadataWritten(UUID, Data)
        case retakeTapped
        case usePhotoTapped
        case flashTapped
        case switchCameraTapped
        case cameraSwitched(Result<[CameraZoomOption], CameraClientError>)
        case zoomTapped(CameraZoomOption)
        case zoomApplied(CameraZoomOption)
        case errorDismissed
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case dismiss
            case photoSelected(Data)
        }
    }

    @Dependency(\.cameraClient) var cameraClient
    @Dependency(\.locationClient) var locationClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.permissionStatus = cameraClient.authorizationStatus()
                let orientationEffect: Effect<Action> = .run { [cameraClient] send in
                    for await orientation in cameraClient.observeDeviceOrientation() {
                        await send(.deviceOrientationChanged(orientation))
                    }
                }
                .cancellable(id: "cameraDeviceOrientation", cancelInFlight: true)

                let setupEffect: Effect<Action>
                switch state.permissionStatus {
                case .authorized:
                    setupEffect = prepareSession(position: state.position)
                case .notDetermined:
                    setupEffect = .run { [cameraClient] send in
                        await send(.permissionResolved(await cameraClient.requestAccess()))
                    }
                case .denied:
                    setupEffect = .none
                }
                return .merge(orientationEffect, setupEffect)

            case .deviceOrientationChanged(let orientation):
                state.deviceOrientation = orientation
                return .none

            case .permissionResolved(let isAllowed):
                state.permissionStatus = isAllowed ? .authorized : .denied
                guard isAllowed else { return .none }
                return prepareSession(position: state.position)

            case .sessionPrepared(.success(let session)):
                state.session = session
                state.supportedZoomOptions = cameraClient.supportedZoomOptions(session)
                state.supportsFlash = cameraClient.supportsFlash(session)
                state.selectedZoomOption = defaultZoomOption(from: state.supportedZoomOptions)
                return .merge(
                    .send(.zoomTapped(state.selectedZoomOption)),
                    .send(.startSession)
                )

            case .sessionPrepared(.failure(let error)):
                state.errorMessage = error.errorDescription
                return .none

            case .startSession:
                guard let session = state.session else { return .none }
                return .run { [cameraClient] _ in
                    await cameraClient.startSession(session)
                }

            case .onDisappear:
                guard let session = state.session else {
                    return .cancel(id: "cameraDeviceOrientation")
                }
                return .merge(
                    .cancel(id: "cameraDeviceOrientation"),
                    .run { [cameraClient] _ in
                        await cameraClient.stopSession(session)
                    }
                )

            case .closeTapped:
                return .send(.delegate(.dismiss))

            case .captureTapped:
                guard let session = state.session, !state.isCapturing else { return .none }
                state.isCapturing = true
                state.isWritingMetadata = false
                let captureID = UUID()
                state.activeCaptureID = captureID
                let flashMode = state.supportsFlash ? state.flashMode : .off
                let orientation = state.deviceOrientation
                return .run { [cameraClient, locationClient] send in
                    do {
                        let data = try await cameraClient.capturePhoto(session, flashMode, orientation)
                        await send(.photoCaptured(captureID, .success(data)))
                        let location = await locationClient.currentLocation()
                        let enrichedData = PhotoMetadataWriter.jpegDataByWritingGPS(to: data, location: location)
                        await send(.photoMetadataWritten(captureID, enrichedData))
                    } catch {
                        await send(.photoCaptured(captureID, .failure(.captureFailed)))
                    }
                }

            case .photoCaptured(let captureID, .success(let data)):
                guard state.activeCaptureID == captureID else { return .none }
                state.isCapturing = false
                state.isWritingMetadata = true
                state.capturedPhotoData = data
                return .none

            case .photoCaptured(let captureID, .failure(let error)):
                guard state.activeCaptureID == captureID else { return .none }
                state.isCapturing = false
                state.isWritingMetadata = false
                state.errorMessage = error.errorDescription
                return .none

            case .photoMetadataWritten(let captureID, let data):
                guard state.activeCaptureID == captureID else { return .none }
                state.isWritingMetadata = false
                state.capturedPhotoData = data
                return .none

            case .retakeTapped:
                state.activeCaptureID = nil
                state.isWritingMetadata = false
                state.capturedPhotoData = nil
                return .none

            case .usePhotoTapped:
                guard let data = state.capturedPhotoData, !state.isWritingMetadata else { return .none }
                return .send(.delegate(.photoSelected(data)))

            case .flashTapped:
                guard state.supportsFlash else { return .none }
                state.flashMode = state.flashMode.next
                return .none

            case .switchCameraTapped:
                guard let session = state.session else { return .none }
                state.position = state.position == .back ? .front : .back
                state.flashMode = .off
                let position = state.position
                return .run { [cameraClient] send in
                    do {
                        let zooms = try await cameraClient.switchCamera(session, position)
                        await send(.cameraSwitched(.success(zooms)))
                    } catch {
                        await send(.cameraSwitched(.failure(.configurationFailed)))
                    }
                }

            case .cameraSwitched(.success(let zooms)):
                state.supportedZoomOptions = zooms
                state.selectedZoomOption = defaultZoomOption(from: zooms)
                if let session = state.session {
                    state.supportsFlash = cameraClient.supportsFlash(session)
                }
                return .send(.zoomTapped(state.selectedZoomOption))

            case .cameraSwitched(.failure(let error)):
                state.errorMessage = error.errorDescription
                return .none

            case .zoomTapped(let option):
                guard let session = state.session else { return .none }
                state.selectedZoomOption = option
                return .run { [cameraClient] send in
                    try? await cameraClient.setZoom(session, option)
                    await send(.zoomApplied(option))
                }

            case .zoomApplied:
                return .none

            case .errorDismissed:
                state.errorMessage = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func prepareSession(position: CameraPosition) -> Effect<Action> {
        .run { [cameraClient] send in
            do {
                await send(.sessionPrepared(.success(try await cameraClient.makeSession(position))))
            } catch let error as CameraClientError {
                await send(.sessionPrepared(.failure(error)))
            } catch {
                await send(.sessionPrepared(.failure(.configurationFailed)))
            }
        }
    }

    private func defaultZoomOption(from options: [CameraZoomOption]) -> CameraZoomOption {
        options.first { abs($0.displayFactor - 1) < 0.01 } ?? options.first ?? .one
    }

}
