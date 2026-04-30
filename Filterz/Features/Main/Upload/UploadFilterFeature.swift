// UploadFilterFeature.swift

import ComposableArchitecture
import CoreLocation
import ImageIO
import MapKit
import UIKit

struct ImageMetadata: Equatable, Sendable {
    var cameraModel: String?
    var format: String?
    var lensSpec: String?
    var megapixels: String?
    var resolution: String?
    var fileSize: String?
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var dateTimeOriginal: String?
}

@Reducer
struct UploadFilterFeature {

    static let categories = ["푸드", "인물", "풍경", "야경", "별"]

    @ObservableState
    struct State: Equatable {
        var filterName: String = ""
        var selectedCategory: String? = nil
        var selectedImageData: Data? = nil
        var displayThumbnail: Data? = nil
        var mapSnapshotData: Data? = nil
        var imageMetadata: ImageMetadata? = nil
        var filterDescription: String = ""
        var price: String = ""
        var isUploading: Bool = false
        var errorMessage: String? = nil
        var isSaveSucceeded: Bool = false
    }

    enum Action: Sendable {
        case filterNameChanged(String)
        case categorySelected(String)
        case imageSelected(Data?)
        case filterDescriptionChanged(String)
        case priceChanged(String)
        case saveTapped
        case imageProcessed(thumbnail: Data?, metadata: ImageMetadata?)
        case mapSnapshotGenerated(Data?)
        case createFilterResponse(Result<FilterResponseDTO, Error>)
        case errorDismissed
        case successAlertDismissed
        case locationResolved(String)
    }

    @Dependency(\.filterClient) var filterClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {

            case .filterNameChanged(let name):
                state.filterName = name
                return .none

            case .categorySelected(let category):
                state.selectedCategory = category
                return .none

            case .imageSelected(let data):
                state.selectedImageData = data
                state.displayThumbnail = nil
                state.mapSnapshotData = nil
                state.imageMetadata = nil
                guard let data else { return .none }
                return .run { send in
                    let thumbTask = Task.detached(priority: .userInitiated) {
                        makeThumbnail(data, maxSide: 600)
                    }
                    let metaTask = Task.detached(priority: .userInitiated) {
                        extractDisplayMetadata(from: data)
                    }
                    let (t, m) = await (thumbTask.value, metaTask.value)
                    await send(.imageProcessed(thumbnail: t, metadata: m))
                    guard let lat = m.latitude, let lon = m.longitude else { return }
                    async let addr = reverseGeocode(lat: lat, lon: lon)
                    async let snap = makeMapSnapshot(lat: lat, lon: lon)
                    if let a = await addr { await send(.locationResolved(a)) }
                    await send(.mapSnapshotGenerated(await snap))
                }

            case .imageProcessed(let thumbnail, let metadata):
                state.displayThumbnail = thumbnail
                state.imageMetadata = metadata
                return .none

            case .mapSnapshotGenerated(let data):
                state.mapSnapshotData = data
                return .none

            case .filterDescriptionChanged(let desc):
                state.filterDescription = desc
                return .none

            case .priceChanged(let price):
                state.price = price
                return .none

            case .saveTapped:
                let name = state.filterName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else {
                    state.errorMessage = "필터명을 입력해주세요."
                    return .none
                }
                guard let category = state.selectedCategory else {
                    state.errorMessage = "카테고리를 선택해주세요."
                    return .none
                }
                guard let imageData = state.selectedImageData else {
                    state.errorMessage = "대표 사진을 등록해주세요."
                    return .none
                }
                let desc = state.filterDescription.trimmingCharacters(in: .whitespaces)
                guard !desc.isEmpty else {
                    state.errorMessage = "필터 소개를 입력해주세요."
                    return .none
                }
                let priceDigits = state.price.filter { $0.isNumber }
                guard let price = Int(priceDigits), price > 0 else {
                    state.errorMessage = "올바른 판매 가격을 입력해주세요."
                    return .none
                }

                state.isUploading = true

                return .run { [filterClient] send in
                    let jpegData = compressUnder2MB(imageData)
                    let photoMeta = buildPhotoMetadataDTO(from: imageData)

                    // Step 1: 이미지 업로드
                    let fileResponse: FileResponseDTO = try await filterClient.uploadFile([jpegData])

                    // Step 2: 필터 생성
                    let query = CreateFilterRequestDTO(
                        category: category,
                        title: name,
                        description: desc,
                        files: fileResponse.files,
                        price: price,
                        photoMetadata: photoMeta,
                        filterValues: FilterValuesDTO(
                            brightness: 0, exposure: 0, contrast: 0,
                            saturation: 0, sharpness: 0, blur: 0,
                            vignette: 0, noiseReduction: 0, highlights: 0,
                            shadows: 0, temperature: 0, blackPoint: 0
                        )
                    )
                    let result: FilterResponseDTO = try await filterClient.createFilter(query)
                    await send(.createFilterResponse(.success(result)))
                } catch: { error, send in
                    await send(.createFilterResponse(.failure(error)))
                }

            case .createFilterResponse(.success):
                state.isUploading = false
                state.isSaveSucceeded = true
                state.filterName = ""
                state.selectedCategory = nil
                state.selectedImageData = nil
                state.displayThumbnail = nil
                state.mapSnapshotData = nil
                state.imageMetadata = nil
                state.filterDescription = ""
                state.price = ""
                return .none

            case .createFilterResponse(.failure(let error)):
                state.isUploading = false
                state.errorMessage = (error as? NetworkError)?.errorDescription
                    ?? error.localizedDescription
                return .none

            case .errorDismissed:
                state.errorMessage = nil
                return .none

            case .successAlertDismissed:
                state.isSaveSucceeded = false
                return .none

            case .locationResolved(let address):
                state.imageMetadata?.address = address
                return .none
            }
        }
    }
}

// MARK: - EXIF Helpers

private func extractDisplayMetadata(from data: Data) -> ImageMetadata {
    var meta = ImageMetadata()

    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
    else {
        let bytes = data.count
        meta.fileSize = bytes >= 1_000_000
            ? String(format: "%.1fMB", Double(bytes) / 1_000_000.0)
            : String(format: "%.0fKB", Double(bytes) / 1_000.0)
        return meta
    }

    let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any]
    let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
    let gps  = props[kCGImagePropertyGPSDictionary  as String] as? [String: Any]

    meta.cameraModel = tiff?[kCGImagePropertyTIFFModel as String] as? String

    let uti = (CGImageSourceGetType(source) as String?) ?? ""
    if uti.contains("heif") || uti.contains("heic") { meta.format = "HEIC" }
    else if uti.contains("jpeg") { meta.format = "JPEG" }
    else if uti.contains("png")  { meta.format = "PNG" }

    // 렌즈 스펙: "와이드 카메라 - 26 mm f/1.5 ISO 400"
    let focal35mm = (exif?[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? NSNumber)?.intValue
    let aperture  = (exif?[kCGImagePropertyExifFNumber as String] as? NSNumber)?.doubleValue
    let isoArr    = exif?[kCGImagePropertyExifISOSpeedRatings as String] as? [Any]
    let isoValue  = isoArr?.first.flatMap { $0 as? NSNumber }?.intValue

    var lensComponents: [String] = []
    if let f = focal35mm {
        let label = f < 20 ? "울트라 와이드 카메라" : f <= 40 ? "와이드 카메라" : "망원 카메라"
        lensComponents.append("\(label) - \(f) mm")
    }
    if let a = aperture { lensComponents.append(String(format: "f/%.1f", a)) }
    if let i = isoValue { lensComponents.append("ISO \(i)") }
    meta.lensSpec = lensComponents.isEmpty ? nil : lensComponents.joined(separator: " ")

    if let w = (props[kCGImagePropertyPixelWidth  as String] as? NSNumber)?.intValue,
       let h = (props[kCGImagePropertyPixelHeight as String] as? NSNumber)?.intValue {
        meta.megapixels = String(format: "%.0fMP", (Double(w * h) / 1_000_000.0).rounded())
        meta.resolution = "\(w) × \(h)"
    }

    let byteCount = data.count
    let mb = Double(byteCount) / 1_048_576.0
    meta.fileSize = mb >= 1.0
        ? String(format: "%.1fMB", mb)
        : String(format: "%.0fKB", Double(byteCount) / 1_024.0)

    // GPS
    if let latRef = gps?[kCGImagePropertyGPSLatitudeRef  as String] as? String,
       let lat    = gps?[kCGImagePropertyGPSLatitude     as String] as? Double,
       let lonRef = gps?[kCGImagePropertyGPSLongitudeRef as String] as? String,
       let lon    = gps?[kCGImagePropertyGPSLongitude    as String] as? Double {
        meta.latitude  = latRef == "S" ? -lat : lat
        meta.longitude = lonRef == "W" ? -lon : lon
    }

    // dateTimeOriginal: "YYYY:MM:DD HH:MM:SS" → 사용자 친화적 표시
    if let exifDate = exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String {
        meta.dateTimeOriginal = formatExifDate(exifDate)
    }

    return meta
}

// MARK: - Image Helpers

private func makeMapSnapshot(lat: Double, lon: Double) async -> Data? {
    let options = MKMapSnapshotter.Options()
    options.region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    )
    options.size = CGSize(width: 120, height: 120)
    options.scale = 2.0
    guard let snapshot = try? await MKMapSnapshotter(options: options).start() else { return nil }
    let renderer = UIGraphicsImageRenderer(size: snapshot.image.size)
    let annotated = renderer.image { _ in
        snapshot.image.draw(at: .zero)
        let coord = snapshot.point(for: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        let pinSize: CGFloat = 10
        UIColor.red.setFill()
        UIBezierPath(ovalIn: CGRect(x: coord.x - pinSize / 2, y: coord.y - pinSize / 2, width: pinSize, height: pinSize)).fill()
    }
    return annotated.jpegData(compressionQuality: 0.85)
}

private func makeThumbnail(_ data: Data, maxSide: CGFloat) -> Data? {
    guard let image = UIImage(data: data) else { return nil }
    let scale = min(maxSide / image.size.width, maxSide / image.size.height, 1.0)
    guard scale < 1.0 else { return image.jpegData(compressionQuality: 0.85) }
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let renderer = UIGraphicsImageRenderer(size: size)
    let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    return resized.jpegData(compressionQuality: 0.85)
}

private func compressUnder2MB(_ data: Data) -> Data {
    let limit = 2 * 1024 * 1024  // 2MB

    guard let image = UIImage(data: data) else { return data }

    // 1. 리사이즈 없이 품질만 줄여보기
    for quality: CGFloat in [0.8, 0.6, 0.4, 0.2] {
        if let compressed = image.jpegData(compressionQuality: quality),
           compressed.count < limit {
            return compressed
        }
    }

    // 2. 긴 변을 1920px 이하로 축소 후 재압축
    let maxSide: CGFloat = 1920
    let scale = min(maxSide / image.size.width, maxSide / image.size.height, 1.0)
    let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let renderer = UIGraphicsImageRenderer(size: targetSize)
    let resized = renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: targetSize))
    }

    for quality: CGFloat in [0.8, 0.6, 0.4, 0.2, 0.1] {
        if let compressed = resized.jpegData(compressionQuality: quality),
           compressed.count < limit {
            return compressed
        }
    }

    return resized.jpegData(compressionQuality: 0.1) ?? data
}

private func buildPhotoMetadataDTO(from data: Data) -> PhotoMetadataDTO? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
    else { return nil }

    let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any]
    let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
    let gps  = props[kCGImagePropertyGPSDictionary  as String] as? [String: Any]

    let camera      = tiff?[kCGImagePropertyTIFFModel as String] as? String
    let lensInfo    = exif?[kCGImagePropertyExifLensModel as String] as? String
    let focalLength = (exif?[kCGImagePropertyExifFocalLength as String] as? NSNumber).map { Float($0.floatValue) }

    let uti = (CGImageSourceGetType(source) as String?) ?? ""
    let format: String?
    if uti.contains("heif") || uti.contains("heic") { format = "HEIC" }
    else if uti.contains("jpeg") { format = "JPEG" }
    else if uti.contains("png") { format = "PNG" }
    else { format = nil }

    let aperture = (exif?[kCGImagePropertyExifFNumber as String] as? NSNumber).map { Float($0.floatValue) }

    let iso: Int?
    if let isoRaw = exif?[kCGImagePropertyExifISOSpeedRatings as String] as? [Any],
       let isoNum = isoRaw.first.flatMap({ $0 as? NSNumber }) {
        iso = isoNum.intValue
    } else {
        iso = nil
    }

    let shutterSpeed: String?
    if let exp = exif?[kCGImagePropertyExifExposureTime as String] as? Double, exp > 0 {
        shutterSpeed = exp < 1
            ? "1/\(Int((1.0 / exp).rounded()))"
            : String(format: "%.1fs", exp)
    } else {
        shutterSpeed = nil
    }

    let dateTimeOriginal: String?
    if let exifDate = exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String {
        dateTimeOriginal = exifDateToISO8601(exifDate)
    } else {
        dateTimeOriginal = nil
    }

    let pixelWidth  = (props[kCGImagePropertyPixelWidth  as String] as? NSNumber)?.intValue
    let pixelHeight = (props[kCGImagePropertyPixelHeight as String] as? NSNumber)?.intValue
    let fileSize    = Double(data.count) / 1_048_576.0

    let latitude: Float?
    let longitude: Float?
    if let latRef = gps?[kCGImagePropertyGPSLatitudeRef  as String] as? String,
       let lat    = gps?[kCGImagePropertyGPSLatitude     as String] as? Double,
       let lonRef = gps?[kCGImagePropertyGPSLongitudeRef as String] as? String,
       let lon    = gps?[kCGImagePropertyGPSLongitude    as String] as? Double {
        latitude  = Float(latRef == "S" ? -lat : lat)
        longitude = Float(lonRef == "W" ? -lon : lon)
    } else {
        latitude  = nil
        longitude = nil
    }

    return PhotoMetadataDTO(
        camera: camera,
        lensInfo: lensInfo,
        focalLength: focalLength,
        aperture: aperture,
        iso: iso,
        shutterSpeed: shutterSpeed,
        pixelWidth: pixelWidth,
        pixelHeight: pixelHeight,
        fileSize: fileSize,
        format: format,
        dateTimeOriginal: dateTimeOriginal,
        latitude: latitude,
        longitude: longitude
    )
}

private func reverseGeocode(lat: Double, lon: Double) async -> String? {
    let location = CLLocation(latitude: lat, longitude: lon)
    guard let placemarks = try? await CLGeocoder().reverseGeocodeLocation(
        location,
        preferredLocale: Locale(identifier: "ko_KR")
    ), let p = placemarks.first else { return nil }

    let city = (p.administrativeArea ?? "")
        .replacingOccurrences(of: "특별시", with: "")
        .replacingOccurrences(of: "광역시", with: "")
        .replacingOccurrences(of: "특별자치시", with: "")
        .trimmingCharacters(in: .whitespaces)

    let parts: [String?] = [
        city.isEmpty ? nil : city,
        p.subAdministrativeArea,
        p.thoroughfare,
        p.subThoroughfare
    ]
    let joined = parts.compactMap { $0 }.joined(separator: " ")
    return joined.isEmpty ? nil : joined
}

// EXIF "YYYY:MM:DD HH:MM:SS" → ISO 8601 서버 전송용
private func exifDateToISO8601(_ exifDate: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    guard let date = formatter.date(from: exifDate) else { return exifDate }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return iso.string(from: date)
}

// EXIF "YYYY:MM:DD HH:MM:SS" → 표시용 로컬 날짜 문자열
private func formatExifDate(_ exifDate: String) -> String {
    let inFormatter = DateFormatter()
    inFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
    inFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    guard let date = inFormatter.date(from: exifDate) else { return exifDate }
    let outFormatter = DateFormatter()
    outFormatter.locale = Locale(identifier: "ko_KR")
    outFormatter.dateFormat = "yyyy. MM. dd. a hh:mm"
    outFormatter.timeZone = TimeZone.current
    return outFormatter.string(from: date)
}
