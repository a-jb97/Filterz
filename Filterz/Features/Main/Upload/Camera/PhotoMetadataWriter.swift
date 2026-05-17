import CoreLocation
import Foundation
import ImageIO

enum PhotoMetadataWriter {
    nonisolated static func jpegDataByWritingGPS(to data: Data, location: CLLocation?) -> Data {
        guard let location,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let destinationData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(destinationData, type, 1, nil)
        else {
            return data
        }

        var properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]) ?? [:]
        properties[kCGImagePropertyGPSDictionary as String] = gpsDictionary(for: location)

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return data }
        return destinationData as Data
    }

    nonisolated private static func gpsDictionary(for location: CLLocation) -> [String: Any] {
        let coordinate = location.coordinate
        let timestamp = location.timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy:MM:dd"

        let timeFormatter = DateFormatter()
        timeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        timeFormatter.dateFormat = "HH:mm:ss.SSSSSS"

        return [
            kCGImagePropertyGPSLatitude as String: abs(coordinate.latitude),
            kCGImagePropertyGPSLatitudeRef as String: coordinate.latitude >= 0 ? "N" : "S",
            kCGImagePropertyGPSLongitude as String: abs(coordinate.longitude),
            kCGImagePropertyGPSLongitudeRef as String: coordinate.longitude >= 0 ? "E" : "W",
            kCGImagePropertyGPSAltitude as String: abs(location.altitude),
            kCGImagePropertyGPSAltitudeRef as String: location.altitude >= 0 ? 0 : 1,
            kCGImagePropertyGPSTimeStamp as String: timeFormatter.string(from: timestamp),
            kCGImagePropertyGPSDateStamp as String: dateFormatter.string(from: timestamp)
        ]
    }
}
