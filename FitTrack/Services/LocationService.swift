import Combine
import CoreLocation

/// Foreground, one-shot location requests. Coordinates are never persisted or sent to Firebase.
@MainActor
final class LocationService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    enum Status: Equatable {
        case idle, requestingPermission, locating, available, denied, restricted
        case unavailable(String)
    }

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var location: CLLocation?
    @Published private(set) var status: Status = .idle
    private let manager: CLLocationManager
    private var requested = false

    var isLoading: Bool { status == .requestingPermission || status == .locating }

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        guard !isLoading else { return }
        requested = true
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .notDetermined:
            status = .requestingPermission
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            status = .locating
            manager.requestLocation()
        case .denied:
            location = nil
            status = .denied
        case .restricted:
            location = nil
            status = .restricted
        @unknown default:
            status = .unavailable("Location is unavailable. You can still select a gym manually.")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .denied:
            location = nil
            status = .denied
        case .restricted:
            location = nil
            status = .restricted
        case .authorizedAlways, .authorizedWhenInUse:
            if requested {
                status = .locating
                manager.requestLocation()
            }
        case .notDetermined: break
        @unknown default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard requested else { return }
        guard let latest = locations.last, latest.horizontalAccuracy >= 0 else {
            status = .unavailable("A location could not be determined. Try again or select a gym manually.")
            return
        }
        location = latest
        status = .available
        requested = false
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        requested = false
        location = nil
        status = .unavailable("Location is temporarily unavailable. Try again or select a gym manually.")
    }
}
