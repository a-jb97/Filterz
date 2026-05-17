@preconcurrency import AVFoundation
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
@preconcurrency import CoreMotion
import ImageIO
import SwiftUI
import UIKit

final class LiveFilterCameraController: NSObject, ObservableObject {
    enum CaptureMode: Equatable {
        case photo
        case video
    }

    struct CapturedPhotoResult {
        let data: Data
        let orientation: CameraDeviceOrientation
    }

    @Published var previewImage: UIImage?
    @Published var filterPreviewImages: [String: UIImage] = [:]
    @Published var mode: CaptureMode = .photo
    @Published var isRunning = false
    @Published var isRecording = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var deviceOrientation: CameraDeviceOrientation = .portrait
    @Published var supportedZoomOptions: [CameraZoomOption] = [.one]
    @Published var selectedZoomOption: CameraZoomOption = .one

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "filterz.liveFilterCamera.session")
    private let outputQueue = DispatchQueue(label: "filterz.liveFilterCamera.output", qos: .userInteractive)
    private let motionManager = CMMotionManager()
    private let motionQueue = OperationQueue()
    private let ciContext = CIContext(options: [.workingColorSpace: CGColorSpaceCreateDeviceRGB()])

    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var position: AVCaptureDevice.Position = .back

    private var selectedValues: FilterAdjustmentValues = .neutral
    private var previewFilters: [PurchasedFilterItem] = []
    private var visiblePreviewIDs = Set<String>()
    private var photoDelegate: LivePhotoCaptureDelegate?
    private var lastMainPreviewTime: CFTimeInterval = 0
    private var lastFilterPreviewTime: CFTimeInterval = 0

    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var recordingURL: URL?
    private var recordingStartTime: CMTime?
    private var recordingOrientation: CameraDeviceOrientation?
    private var videoSize: CGSize?

    override init() {
        motionQueue.name = "filterz.liveFilterCamera.motion"
        motionQueue.qualityOfService = .userInteractive
        super.init()
    }

    func start(filters: [PurchasedFilterItem]) {
        previewFilters = filters
        guard !isRunning else { return }
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        startOrientationUpdates()

        Task {
            let hasCameraAccess = await AVCaptureDevice.requestAccess(for: .video)
            let hasMicrophoneAccess = await AVCaptureDevice.requestAccess(for: .audio)
            guard hasCameraAccess else {
                errorMessage = "카메라 권한이 필요합니다."
                return
            }
            if !hasMicrophoneAccess {
                errorMessage = "마이크 권한이 없어 동영상에는 소리가 저장되지 않습니다."
            }
            configureAndStart(includeAudio: hasMicrophoneAccess)
        }
    }

    func stop() {
        guard isRunning else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.motionManager.stopDeviceMotionUpdates()
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            Task { @MainActor in
                self.isRunning = false
                self.previewImage = nil
                self.filterPreviewImages = [:]
                self.photoDelegate = nil
            }
        }
    }

    func setSelectedFilter(_ filter: PurchasedFilterItem?) {
        selectedValues = filter?.filterValues ?? .neutral
    }

    func setFilterSheetVisible(_ isVisible: Bool) {
        if !isVisible {
            visiblePreviewIDs.removeAll()
            filterPreviewImages = [:]
        }
    }

    func setVisiblePreviewIDs(_ ids: Set<String>) {
        visiblePreviewIDs = ids
    }

    func switchMode(_ mode: CaptureMode) {
        guard !isRecording else { return }
        self.mode = mode
    }

    func switchCamera() {
        guard !isRecording else { return }
        position = position == .back ? .front : .back
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureVideoInput(position: self.position)
            self.configureOutputs()
        }
    }

    func capturePhoto() async throws -> CapturedPhotoResult {
        let orientation = currentCaptureOrientation()
        let data = try await captureHighResolutionPhotoData(orientation: orientation)
        guard let filtered = filteredPhotoData(from: data, orientation: orientation) else {
            throw LiveFilterCameraError.photoCaptureFailed
        }
        return CapturedPhotoResult(data: filtered, orientation: orientation)
    }

    func zoomTapped(_ option: CameraZoomOption) {
        guard !isRecording else { return }
        selectedZoomOption = option
        sessionQueue.async { [weak self] in
            guard let self else { return }
            try? self.setZoom(option.deviceFactor)
        }
    }

    func startRecording() {
        guard !isRecording else { return }
        recordingOrientation = currentCaptureOrientation()
        isRecording = true
        recordingStartTime = nil
        recordingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("filterz-\(UUID().uuidString).mov")
    }

    func stopRecording() async throws -> URL {
        guard isRecording else { throw LiveFilterCameraError.recordingFailed }
        isRecording = false

        let writer = assetWriter
        let videoInput = videoWriterInput
        let audioInput = audioWriterInput
        assetWriter = nil
        videoWriterInput = nil
        audioWriterInput = nil
        pixelBufferAdaptor = nil
        recordingStartTime = nil
        recordingOrientation = nil

        guard let writer, let url = recordingURL else {
            throw LiveFilterCameraError.recordingFailed
        }

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        await writer.finishWriting()
        guard writer.status == .completed else {
            throw writer.error ?? LiveFilterCameraError.recordingFailed
        }
        return url
    }

    private func configureAndStart(includeAudio: Bool) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureVideoInput(position: self.position)
            self.session.beginConfiguration()
            if self.session.canSetSessionPreset(.photo) {
                self.session.sessionPreset = .photo
            }
            if includeAudio {
                self.configureAudioInput()
            }
            self.configureOutputs()
            self.session.commitConfiguration()
            self.session.startRunning()

            Task { @MainActor in
                self.isRunning = true
            }
        }
    }

    private func configureVideoInput(position: AVCaptureDevice.Position) {
        session.beginConfiguration()
        if let videoInput {
            session.removeInput(videoInput)
        }

        guard let device = cameraDevice(position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            session.commitConfiguration()
            Task { @MainActor in
                self.errorMessage = "사용 가능한 카메라를 찾을 수 없습니다."
            }
            return
        }

        session.addInput(input)
        videoInput = input
        updateZoomOptions(for: device)
        session.commitConfiguration()
    }

    private func configureAudioInput() {
        guard let device = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }

        session.addInput(input)
        audioInput = input
    }

    private func configureOutputs() {
        if session.canAddOutput(photoOutput), !session.outputs.contains(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
        }

        if let connection = photoOutput.connection(with: .video) {
            let angle = deviceOrientation.captureRotationAngle
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = position == .front
            }
        }

        if session.canAddOutput(videoOutput), !session.outputs.contains(videoOutput) {
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            session.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
        }

        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = position == .front
            }
        }

        if session.canAddOutput(audioOutput), !session.outputs.contains(audioOutput) {
            session.addOutput(audioOutput)
            audioOutput.setSampleBufferDelegate(self, queue: outputQueue)
        }
    }

    private func handleVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let inputImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = inputImage.extent
        let filtered = FilterImageRenderer.filteredImage(from: inputImage, values: selectedValues, extent: extent)
        let timestamp = CACurrentMediaTime()

        if timestamp - lastMainPreviewTime >= 1.0 / 24.0 {
            lastMainPreviewTime = timestamp
            publishMainPreview(filtered, extent: extent)
        }

        if timestamp - lastFilterPreviewTime >= 0.25 {
            lastFilterPreviewTime = timestamp
            publishFilterPreviews(from: inputImage, extent: extent)
        }

        appendVideoFrameIfNeeded(filtered, sampleBuffer: sampleBuffer, extent: extent)
    }

    private func publishMainPreview(_ image: CIImage, extent: CGRect) {
        guard let uiImage = uiImage(from: image, extent: extent) else { return }
        Task { @MainActor in
            self.previewImage = uiImage
        }
    }

    private func publishFilterPreviews(from image: CIImage, extent: CGRect) {
        let visibleFilters = previewFilters
            .filter { visiblePreviewIDs.contains($0.id) }
        guard !visibleFilters.isEmpty else { return }

        var nextImages: [String: UIImage] = [:]
        let scale = min(220 / max(extent.width, extent.height), 1)
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let previewImage = image.transformed(by: transform)
        let previewExtent = previewImage.extent

        for filter in visibleFilters {
            let filtered = FilterImageRenderer.filteredImage(
                from: previewImage,
                values: filter.filterValues,
                extent: previewExtent
            )
            if let uiImage = uiImage(from: filtered, extent: previewExtent) {
                nextImages[filter.id] = uiImage
            }
        }

        Task { @MainActor in
            self.filterPreviewImages.merge(nextImages) { _, new in new }
        }
    }

    private func appendVideoFrameIfNeeded(
        _ image: CIImage,
        sampleBuffer: CMSampleBuffer,
        extent: CGRect
    ) {
        guard isRecording else { return }
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let outputFrame = videoFrameForRecording(image, extent: extent)
        if assetWriter == nil {
            do {
                try prepareWriterIfNeeded(size: outputFrame.extent.size, startTime: presentationTime)
            } catch {
                Task { @MainActor in
                    self.isRecording = false
                    self.errorMessage = error.localizedDescription
                }
                return
            }
        }

        guard let adaptor = pixelBufferAdaptor,
              let input = videoWriterInput,
              input.isReadyForMoreMediaData,
              let pool = adaptor.pixelBufferPool
        else { return }

        var outputBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &outputBuffer) == kCVReturnSuccess,
              let outputBuffer
        else { return }

        ciContext.render(outputFrame.image, to: outputBuffer, bounds: outputFrame.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
        adaptor.append(outputBuffer, withPresentationTime: presentationTime)
    }

    private func videoFrameForRecording(_ image: CIImage, extent: CGRect) -> (image: CIImage, extent: CGRect) {
        guard let recordingOrientation else {
            return (image, extent)
        }

        switch recordingOrientation {
        case .portrait, .portraitUpsideDown:
            return (image, extent)
        case .landscapeLeft:
            return rotatedVideoFrame(image, extent: extent, radians: .pi / 2)
        case .landscapeRight:
            return rotatedVideoFrame(image, extent: extent, radians: -.pi / 2)
        }
    }

    private func rotatedVideoFrame(_ image: CIImage, extent: CGRect, radians: CGFloat) -> (image: CIImage, extent: CGRect) {
        let outputExtent = CGRect(
            origin: .zero,
            size: CGSize(width: extent.height, height: extent.width)
        )
        let rotated = image.transformed(by: CGAffineTransform(rotationAngle: radians))
        let translated = rotated.transformed(
            by: radians < 0
            ? CGAffineTransform(translationX: 0, y: extent.width)
            : CGAffineTransform(translationX: extent.height, y: 0)
        )
        return (translated.cropped(to: outputExtent), outputExtent)
    }

    private func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording,
              let writer = assetWriter,
              writer.status == .writing,
              let input = audioWriterInput,
              input.isReadyForMoreMediaData
        else { return }

        input.append(sampleBuffer)
    }

    private func prepareWriterIfNeeded(size: CGSize, startTime: CMTime) throws {
        guard let url = recordingURL else { throw LiveFilterCameraError.recordingFailed }
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        let renderWidth = max(2, Int(size.width))
        let renderHeight = max(2, Int(size.height))
        let renderSize = CGSize(width: CGFloat(renderWidth), height: CGFloat(renderHeight))
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: renderWidth,
            AVVideoHeightKey: renderHeight
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: renderWidth,
            kCVPixelBufferHeightKey as String: renderHeight
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: attributes
        )

        if writer.canAdd(videoInput) {
            writer.add(videoInput)
        }

        let audioInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 1,
                AVSampleRateKey: 44_100,
                AVEncoderBitRateKey: 64_000
            ]
        )
        audioInput.expectsMediaDataInRealTime = true
        if writer.canAdd(audioInput) {
            writer.add(audioInput)
        }

        writer.startWriting()
        writer.startSession(atSourceTime: startTime)

        assetWriter = writer
        videoWriterInput = videoInput
        audioWriterInput = audioInput
        pixelBufferAdaptor = adaptor
        recordingStartTime = startTime
        videoSize = renderSize
    }

    private func uiImage(from image: CIImage, extent: CGRect) -> UIImage? {
        guard let cgImage = ciContext.createCGImage(image, from: extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func jpegData(from image: CIImage, extent: CGRect) -> Data? {
        guard let uiImage = uiImage(from: image, extent: extent) else { return nil }
        return uiImage.jpegData(compressionQuality: 0.92)
    }

    private func cameraDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        ).devices.first
    }

    private func updateZoomOptions(for device: AVCaptureDevice) {
        let options = supportedZoomOptions(for: device)
        Task { @MainActor in
            self.supportedZoomOptions = options
            self.selectedZoomOption = self.defaultZoomOption(from: options)
            self.zoomTapped(self.selectedZoomOption)
        }
    }

    private func setZoom(_ factor: CGFloat) throws {
        guard let device = videoInput?.device else { return }
        let clamped = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
        try device.lockForConfiguration()
        device.videoZoomFactor = clamped
        device.unlockForConfiguration()
    }

    private func supportedZoomOptions(for device: AVCaptureDevice) -> [CameraZoomOption] {
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

    private func normalizedDisplayFactor(_ factor: CGFloat) -> CGFloat {
        let rounded = (factor * 10).rounded() / 10
        if abs(rounded - rounded.rounded()) < 0.01 {
            return rounded.rounded()
        }
        return rounded
    }

    private func defaultZoomOption(from options: [CameraZoomOption]) -> CameraZoomOption {
        options.first { abs($0.displayFactor - 1) < 0.01 } ?? options.first ?? .one
    }

    private func startOrientationUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.12
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, _ in
            guard let self,
                  let gravity = motion?.gravity,
                  let orientation = CameraDeviceOrientation(gravityX: gravity.x, gravityY: gravity.y)
            else { return }

            Task { @MainActor in
                guard self.deviceOrientation != orientation else { return }
                self.deviceOrientation = orientation
                self.sessionQueue.async { [weak self] in
                    guard let self,
                          let connection = self.photoOutput.connection(with: .video)
                    else { return }
                    let angle = orientation.captureRotationAngle
                    if connection.isVideoRotationAngleSupported(angle) {
                        connection.videoRotationAngle = angle
                    }
                }
            }
        }
    }

    private func captureHighResolutionPhotoData(orientation: CameraDeviceOrientation) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            settings.photoQualityPrioritization = .quality

            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: LiveFilterCameraError.photoCaptureFailed)
                    return
                }

                if let connection = self.photoOutput.connection(with: .video) {
                    let angle = orientation.captureRotationAngle
                    if connection.isVideoRotationAngleSupported(angle) {
                        connection.videoRotationAngle = angle
                    }
                    if connection.isVideoMirroringSupported {
                        connection.isVideoMirrored = self.position == .front
                    }
                }

                let delegate = LivePhotoCaptureDelegate { [weak self] result in
                    Task { @MainActor in
                        self?.photoDelegate = nil
                    }
                    continuation.resume(with: result)
                }
                self.photoDelegate = delegate
                self.photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    private func currentCaptureOrientation() -> CameraDeviceOrientation {
        if let gravity = motionManager.deviceMotion?.gravity,
           let orientation = CameraDeviceOrientation(gravityX: gravity.x, gravityY: gravity.y) {
            return orientation
        }

        switch UIDevice.current.orientation {
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            return CameraDeviceOrientation(deviceOrientation: UIDevice.current.orientation)
        default:
            return deviceOrientation
        }
    }

    private func filteredPhotoData(from data: Data, orientation: CameraDeviceOrientation) -> Data? {
        guard let image = CIImage(data: data) else { return nil }
        let extent = image.extent
        let filtered = FilterImageRenderer.filteredImage(from: image, values: selectedValues, extent: extent)
        var options: [CIImageRepresentationOption: Any] = [
            kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.92
        ]
        if let orientationValue = imageOrientationValue(from: data) {
            options[kCGImagePropertyOrientation as CIImageRepresentationOption] = orientationValue
        }
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let jpeg = ciContext.jpegRepresentation(
                of: filtered,
                colorSpace: colorSpace,
                options: options
              )
        else {
            return jpegData(from: filtered, extent: extent)
        }
        return jpeg
    }

    private func imageOrientationValue(from data: Data) -> Int? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let orientation = properties[kCGImagePropertyOrientation] as? Int
        else {
            return nil
        }
        return orientation
    }
}

extension LiveFilterCameraController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if output is AVCaptureVideoDataOutput {
            self.handleVideoSampleBuffer(sampleBuffer)
        } else if output is AVCaptureAudioDataOutput {
            self.appendAudioSampleBuffer(sampleBuffer)
        }
    }
}

private enum LiveFilterCameraError: LocalizedError {
    case photoCaptureFailed
    case recordingFailed

    var errorDescription: String? {
        switch self {
        case .photoCaptureFailed:
            return "사진 촬영에 실패했습니다."
        case .recordingFailed:
            return "동영상 저장에 실패했습니다."
        }
    }
}

private final class LivePhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
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
            completion(.failure(LiveFilterCameraError.photoCaptureFailed))
            return
        }

        completion(.success(data))
    }
}
