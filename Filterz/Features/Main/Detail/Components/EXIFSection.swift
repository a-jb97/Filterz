import SwiftUI
import MapKit
import CoreLocation

struct EXIFSection: View {
    let exif: FilterExifData
    var onMapTapped: (EXIFMapLocation) -> Void = { _ in }

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
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.filterzBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.filterzGray30.opacity(0.9), lineWidth: 1)
                )
        )
    }

    private var headerRow: some View {
        HStack {
            Text(exif.camera ?? "카메라 정보 없음")
                .font(.pretendard(13, weight: .semibold))
                .foregroundColor(.filterzGray30)
            Spacer()
            Text(exif.format ?? "EXIF")
                .font(.pretendard(11, weight: .bold))
                .foregroundColor(Color.filterzBackground)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.filterzAccent)
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
            ZStack(alignment: .topTrailing) {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    Marker("", coordinate: coordinate)
                        .tint(Color.filterzAccent)
                }
                .allowsHitTesting(false)

                Button {
                    onMapTapped(EXIFMapLocation(latitude: Double(lat), longitude: Double(lon)))
                } label: {
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("촬영 위치 지도 열기")

                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(6)
                    .background(
                        Circle().fill(Color.filterzAccent)
                    )
                    .padding(8)
                    .allowsHitTesting(false)
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var specsText: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let lensInfo = exif.lensInfo, let focalLength = exif.focalLength,
               let aperture = exif.aperture, let iso = exif.iso {
                Text("\(lensInfo) - \(Int(focalLength))mm f/\(String(format: "%.1f", aperture)) ISO \(iso)")
                    .font(.pretendard(12, weight: .medium))
                    .foregroundColor(.filterzGray30)
            }

            let resolutionText = [exif.megapixels, exif.dimensionsFormatted, exif.fileSizeFormatted]
                .compactMap { $0 }
                .joined(separator: " • ")
            if !resolutionText.isEmpty {
                Text(resolutionText)
                    .font(.pretendard(12, weight: .medium))
                    .foregroundColor(.filterzGray30)
            }

            if let date = exif.dateTimeOriginalFormatted {
                Text(date)
                    .font(.pretendard(12, weight: .medium))
                    .foregroundColor(.filterzGray30)
            }
        }
    }
}

private struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct EXIFMapSheetView: View {
    let location: EXIFMapLocation
    @Environment(\.dismiss) private var dismiss

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: location.latitude,
            longitude: location.longitude
        )
    }

    var body: some View {
        NavigationStack {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))) {
                Marker("촬영 위치", coordinate: coordinate)
                    .tint(Color.filterzAccent)
            }
            .mapControls {
                MapCompass()
                MapScaleView()
                MapUserLocationButton()
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("촬영 위치")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .tint(.filterzGray30)
                    .accessibilityLabel("닫기")
                }
            }
        }
    }
}
