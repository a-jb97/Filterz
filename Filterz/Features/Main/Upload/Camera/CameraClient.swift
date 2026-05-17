@preconcurrency import AVFoundation
import ComposableArchitecture
@preconcurrency import CoreMotion
import Foundation
import UIKit

enum CameraPermissionStatus: Equatable, Sendable {
    case authorized
    case notDetermined
    case denied
}

enum CameraPosition: Equatable, Sendable {
    case back
    case front

    var capturePosition: AVCaptureDevice.Position {
        switch self {
        case .back: return .back
        case .front: return .front
        }
    }
}

enum CameraFlashMode: Equatable, Sendable {
    case off
    case on
    case auto

    var captureMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: return .off
        case .on: return .on
        case .auto: return .auto
        }
    }

    var iconName: String {
        switch self {
        case .off: return "bolt.slash.fill"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.a.fill"
        }
    }

    var next: CameraFlashMode {
        switch self {
        case .off: return .on
        case .on: return .auto
        case .auto: return .off
        }
    }
}

struct CameraZoomOption: Equatable, Sendable, Identifiable {
    let displayFactor: CGFloat
    let deviceFactor: CGFloat

    var id: CGFloat { displayFactor }

    nonisolated static let one = CameraZoomOption(displayFactor: 1, deviceFactor: 1)
}

enum CameraDeviceOrientation: Equatable, Sendable {
    case portrait
    case portraitUpsideDown
    case landscapeLeft
    case landscapeRight

    nonisolated init(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        case .landscapeLeft:
            self = .landscapeLeft
        case .landscapeRight:
            self = .landscapeRight
        default:
            self = .portrait
        }
    }

    nonisolated init?(gravityX: Double, gravityY: Double) {
        let threshold = 0.65
        let absX = abs(gravityX)
        let absY = abs(gravityY)

        guard max(absX, absY) >= threshold else { return nil }

        if absY >= absX {
            self = gravityY < 0 ? .portrait : .portraitUpsideDown
        } else {
            self = gravityX < 0 ? .landscapeLeft : .landscapeRight
        }
    }

    var captureRotationAngle: CGFloat {
        switch self {
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return 270
        case .landscapeLeft:
            return 0
        case .landscapeRight:
            return 180
        }
    }

    var controlRotationDegrees: Double {
        switch self {
        case .portrait:
            return 0
        case .portraitUpsideDown:
            return 180
        case .landscapeLeft:
            return 90
        case .landscapeRight:
            return -90
        }
    }
}

enum CameraClientError: LocalizedError, Equatable, Sendable {
    case unavailable
    case configurationFailed
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "사용 가능한 카메라를 찾을 수 없습니다."
        case .configurationFailed:
            return "카메라를 준비할 수 없습니다."
        case .captureFailed:
            return "사진 촬영에 실패했습니다."
        }
    }
}

final class CameraSession: @unchecked Sendable, Equatable {
    static func == (lhs: CameraSession, rhs: CameraSession) -> Bool {
        lhs === rhs
    }

    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) fileprivate let output = AVCapturePhotoOutput()
    fileprivate let queue = DispatchQueue(label: "filterz.camera.session")
    nonisolated(unsafe) fileprivate var input: AVCaptureDeviceInput?
    nonisolated(unsafe) fileprivate var position: CameraPosition = .back
    nonisolated(unsafe) fileprivate var photoDelegate: PhotoCaptureDelegate?

    nonisolated var supportsFlash: Bool {
        switch position {
        case .back:
            return output.supportedFlashModes.contains(.on)
        case .front:
            return false
        }
    }
}

struct CameraClient: Sendable {
    var authorizationStatus: @Sendable () -> CameraPermissionStatus
    var requestAccess: @Sendable () async -> Bool
    var makeSession: @Sendable (_ position: CameraPosition) async throws -> CameraSession
    var startSession: @Sendable (_ session: CameraSession) async -> Void
    var stopSession: @Sendable (_ session: CameraSession) async -> Void
    var capturePhoto: @Sendable (_ session: CameraSession, _ flashMode: CameraFlashMode, _ orientation: CameraDeviceOrientation) async throws -> Data
    var switchCamera: @Sendable (_ session: CameraSession, _ position: CameraPosition) async throws -> [CameraZoomOption]
    var setZoom: @Sendable (_ session: CameraSession, _ option: CameraZoomOption) async throws -> Void
    var supportedZoomOptions: @Sendable (_ session: CameraSession) -> [CameraZoomOption]
    var supportsFlash: @Sendable (_ session: CameraSession) -> Bool
    var observeDeviceOrientation: @Sendable () -> AsyncStream<CameraDeviceOrientation>
}

extension CameraClient: DependencyKey {
    static let liveValue = CameraClient(
        authorizationStatus: {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                return .authorized
            case .notDetermined:
                return .notDetermined
            case .denied, .restricted:
                return .denied
            @unknown default:
                return .denied
            }
        },
        requestAccess: {
            await AVCaptureDevice.requestAccess(for: .video)
        },
        makeSession: { position in
            try await makeCameraSession(position: position)
        },
        startSession: { cameraSession in
            await cameraSession.queue.run {
                guard !cameraSession.session.isRunning else { return }
                cameraSession.session.startRunning()
            }
        },
        stopSession: { cameraSession in
            await cameraSession.queue.run {
                guard cameraSession.session.isRunning else { return }
                cameraSession.session.stopRunning()
            }
        },
        capturePhoto: { cameraSession, flashMode, orientation in
            try await liveCapturePhoto(cameraSession, flashMode: flashMode, orientation: orientation)
        },
        switchCamera: { cameraSession, position in
            try await liveSwitchCamera(cameraSession, to: position)
            return liveSupportedZoomOptions(for: cameraSession)
        },
        setZoom: { cameraSession, option in
            try await liveSetZoom(option.deviceFactor, on: cameraSession)
        },
        supportedZoomOptions: { cameraSession in
            liveSupportedZoomOptions(for: cameraSession)
        },
        supportsFlash: { cameraSession in
            cameraSession.supportsFlash
        },
        observeDeviceOrientation: {
            AsyncStream { continuation in
                let box = MotionBox()
                let manager = box.manager
                guard manager.isDeviceMotionAvailable else {
                    continuation.yield(.portrait)
                    continuation.finish()
                    return
                }

                manager.deviceMotionUpdateInterval = 0.12
                manager.startDeviceMotionUpdates(to: box.queue) { motion, _ in
                    guard let gravity = motion?.gravity,
                          let orientation = CameraDeviceOrientation(gravityX: gravity.x, gravityY: gravity.y)
                    else {
                        return
                    }
                    continuation.yield(orientation)
                }

                continuation.onTermination = { _ in
                    manager.stopDeviceMotionUpdates()
                }
            }
        }
    )

    static let testValue = CameraClient(
        authorizationStatus: { .authorized },
        requestAccess: { true },
        makeSession: { _ in throw CameraClientError.unavailable },
        startSession: { _ in },
        stopSession: { _ in },
        capturePhoto: { _, _, _ in Data() },
        switchCamera: { _, _ in [.one] },
        setZoom: { _, _ in },
        supportedZoomOptions: { _ in [.one] },
        supportsFlash: { _ in true },
        observeDeviceOrientation: {
            AsyncStream { continuation in
                continuation.finish()
            }
        }
    )
}

extension DependencyValues {
    var cameraClient: CameraClient {
        get { self[CameraClient.self] }
        set { self[CameraClient.self] = newValue }
    }
}

private func makeCameraSession(position: CameraPosition) async throws -> CameraSession {
    let cameraSession = CameraSession()
    try await cameraSession.queue.run {
        cameraSession.session.beginConfiguration()
        cameraSession.session.sessionPreset = .photo

        guard let device = cameraDevice(position: position.capturePosition),
              let input = try? AVCaptureDeviceInput(device: device),
              cameraSession.session.canAddInput(input),
              cameraSession.session.canAddOutput(cameraSession.output)
        else {
            cameraSession.session.commitConfiguration()
            throw CameraClientError.unavailable
        }

        cameraSession.session.addInput(input)
        cameraSession.session.addOutput(cameraSession.output)
        cameraSession.input = input
        cameraSession.position = position
        cameraSession.output.maxPhotoQualityPrioritization = .quality
        cameraSession.session.commitConfiguration()
    }
    return cameraSession
}

private func liveSwitchCamera(_ cameraSession: CameraSession, to position: CameraPosition) async throws {
    try await cameraSession.queue.run {
        guard let device = cameraDevice(position: position.capturePosition),
              let input = try? AVCaptureDeviceInput(device: device)
        else {
            throw CameraClientError.unavailable
        }

        cameraSession.session.beginConfiguration()
        if let currentInput = cameraSession.input {
            cameraSession.session.removeInput(currentInput)
        }
        guard cameraSession.session.canAddInput(input) else {
            cameraSession.session.commitConfiguration()
            throw CameraClientError.configurationFailed
        }
        cameraSession.session.addInput(input)
        cameraSession.input = input
        cameraSession.position = position
        cameraSession.session.commitConfiguration()
    }
}

private func liveCapturePhoto(
    _ cameraSession: CameraSession,
    flashMode: CameraFlashMode,
    orientation: CameraDeviceOrientation
) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        settings.photoQualityPrioritization = .quality
        if cameraSession.supportsFlash {
            settings.flashMode = flashMode.captureMode
        }
        if let connection = cameraSession.output.connection(with: .video),
           connection.isVideoRotationAngleSupported(orientation.captureRotationAngle) {
            connection.videoRotationAngle = orientation.captureRotationAngle
        }

        let delegate = PhotoCaptureDelegate { result in
            continuation.resume(with: result)
            cameraSession.photoDelegate = nil
        }

        cameraSession.photoDelegate = delegate
        cameraSession.output.capturePhoto(with: settings, delegate: delegate)
    }
}

private func liveSetZoom(_ factor: CGFloat, on cameraSession: CameraSession) async throws {
    try await cameraSession.queue.run {
        guard let device = cameraSession.input?.device else { return }
        let clampedFactor = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
        try device.lockForConfiguration()
        device.videoZoomFactor = clampedFactor
        device.unlockForConfiguration()
    }
}

nonisolated private func liveSupportedZoomOptions(for cameraSession: CameraSession) -> [CameraZoomOption] {
    guard let device = cameraSession.input?.device else { return [.one] }

    let minZoom = device.minAvailableVideoZoomFactor
    let maxZoom = device.maxAvailableVideoZoomFactor
    let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors
        .map { CGFloat(truncating: $0) }
        .filter { $0 >= minZoom && $0 <= maxZoom }
        .sorted()

    if device.position == .back, !switchOvers.isEmpty {
        let wideDeviceFactor = switchOvers.first ?? 1
        let digitalZoomFactors: [CGFloat] = [2 * wideDeviceFactor]
            .filter { $0 >= minZoom && $0 <= maxZoom }
        let lensFactors = ([minZoom] + switchOvers + digitalZoomFactors)
            .reduce(into: [CGFloat]()) { result, factor in
                guard !result.contains(where: { abs($0 - factor) < 0.01 }) else { return }
                result.append(factor)
            }
        return lensFactors.map { factor in
            CameraZoomOption(
                displayFactor: normalizedDisplayFactor(factor / wideDeviceFactor),
                deviceFactor: factor
            )
        }
        .sorted { $0.displayFactor < $1.displayFactor }
    }

    let candidates: [CGFloat] = device.position == .back ? [1, 2, 3] : [1, 2]
    let options = candidates
        .filter { $0 >= minZoom && $0 <= maxZoom }
        .map { CameraZoomOption(displayFactor: $0, deviceFactor: $0) }
    return options.isEmpty ? [.one] : options
}

nonisolated private func normalizedDisplayFactor(_ factor: CGFloat) -> CGFloat {
    let rounded = (factor * 10).rounded() / 10
    if abs(rounded - rounded.rounded()) < 0.01 {
        return rounded.rounded()
    }
    return rounded
}


private func cameraDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
    let deviceTypes: [AVCaptureDevice.DeviceType] = [
        .builtInTripleCamera,
        .builtInDualWideCamera,
        .builtInDualCamera,
        .builtInWideAngleCamera
    ]
    let discovery = AVCaptureDevice.DiscoverySession(
        deviceTypes: deviceTypes,
        mediaType: .video,
        position: position
    )
    return discovery.devices.first
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<Data, Error>) -> Void

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            completion(.failure(error))
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(CameraClientError.captureFailed))
            return
        }

        completion(.success(data))
    }
}

private final class MotionBox: @unchecked Sendable {
    let manager = CMMotionManager()
    let queue = OperationQueue()

    init() {
        queue.name = "filterz.camera.motion"
        queue.qualityOfService = .userInteractive
    }
}

private extension DispatchQueue {
    func run<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func run(_ work: @escaping () -> Void) async {
        await withCheckedContinuation { continuation in
            async {
                work()
                continuation.resume()
            }
        }
    }
}
