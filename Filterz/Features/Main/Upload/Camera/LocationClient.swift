import ComposableArchitecture
import CoreLocation
import Foundation

struct LocationClient: Sendable {
    var currentLocation: @Sendable () async -> CLLocation?
}

extension LocationClient: DependencyKey {
    static let liveValue = LocationClient {
        await CurrentLocationProvider().currentLocation()
    }

    static let testValue = LocationClient {
        nil
    }
}

extension DependencyValues {
    var locationClient: LocationClient {
        get { self[LocationClient.self] }
        set { self[LocationClient.self] = newValue }
    }
}

private final class CurrentLocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    private var authorizationContinuation: CheckedContinuation<Bool, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func currentLocation() async -> CLLocation? {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return await requestSingleLocation()
        case .notDetermined:
            let isAllowed = await requestAuthorization()
            guard isAllowed else { return nil }
            return await requestSingleLocation()
        case .denied, .restricted:
            return nil
        @unknown default:
            return nil
        }
    }

    private func requestSingleLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            manager.requestLocation()
        }
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            self.authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationContinuation?.resume(returning: locations.last)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            authorizationContinuation?.resume(returning: true)
            authorizationContinuation = nil
        case .denied, .restricted:
            authorizationContinuation?.resume(returning: false)
            authorizationContinuation = nil
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        case .notDetermined:
            break
        @unknown default:
            authorizationContinuation?.resume(returning: false)
            authorizationContinuation = nil
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
    }
}
