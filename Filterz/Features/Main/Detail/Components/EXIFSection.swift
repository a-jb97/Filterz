import SwiftUI
import MapKit
import CoreLocation

struct EXIFSection: View {
    let exif: FilterExifData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow

            VStack(alignment: .leading, spacing: 12) {
                if exif.latitude != nil && exif.longitude != nil {
                    mapView
                }
                specsText
            }
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.filterzBlackTurquoise)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.filterzTranslucent, lineWidth: 1)
                )
        )
    }

    private var headerRow: some View {
        HStack {
            Text(exif.camera ?? "카메라 정보 없음")
                .font(.pretendard(13, weight: .semibold))
                .foregroundColor(.filterzGray45)
            Spacer()
            Text("EXIF")
                .font(.pretendard(11, weight: .bold))
                .foregroundColor(.filterzGray75)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.filterzGray90)
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var mapView: some View {
        if let lat = exif.latitude, let lon = exif.longitude {
            let coordinate = CLLocationCoordinate2D(
                latitude: Double(lat),
                longitude: Double(lon)
            )
            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))) {
                Marker("", coordinate: coordinate)
                    .tint(Color.filterzAccent)
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(true)
        }
    }

    private var specsText: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let lensInfo = exif.lensInfo, let focalLength = exif.focalLength,
               let aperture = exif.aperture, let iso = exif.iso {
                Text("\(lensInfo) - \(Int(focalLength))mm f/\(String(format: "%.1f", aperture)) ISO \(iso)")
                    .font(.pretendard(12, weight: .medium))
                    .foregroundColor(.filterzGray60)
            }

            if let mp = exif.megapixels, let dims = exif.dimensionsFormatted,
               let size = exif.fileSizeFormatted {
                Text("\(mp) • \(dims) • \(size)")
                    .font(.pretendard(12, weight: .medium))
                    .foregroundColor(.filterzGray60)
            }

            if let date = exif.dateTimeOriginal {
                Text(date)
                    .font(.pretendard(12, weight: .medium))
                    .foregroundColor(.filterzGray60)
            }
        }
    }
}

private struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
