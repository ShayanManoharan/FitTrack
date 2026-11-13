import Combine
import CoreLocation
import Foundation

/// A small test seam around Apple's foreground location manager.
protocol LocationManaging: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var delegate: CLLocationManagerDelegate? { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }
    func requestWhenInUseAuthorization()
    func requestLocation()
    func stopUpdatingLocation()
}

extension CLLocationManager: LocationManaging { }

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
    private let manager: any LocationManaging
    private let requestTimeout: Duration
    private var timeoutTask: Task<Void, Never>?
    private var requested = false

    var isLoading: Bool { status == .requestingPermission || status == .locating }

    init(manager: any LocationManaging = CLLocationManager(), requestTimeout: Duration = .seconds(20)) {
        self.manager = manager
        self.requestTimeout = requestTimeout
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        refreshAuthorization()
    }

    func requestLocation() {
        guard !isLoading else { return }
        requested = true
        location = nil
        refreshAuthorization()
        if authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
    }

    /// Recheck on returning from Settings; never request permission without a user action.
    func refreshAuthorization() {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .notDetermined:
            location = nil
            status = requested ? .requestingPermission : .idle
        case .authorizedAlways, .authorizedWhenInUse:
            if requested {
                if status != .locating { beginLocationRequest() }
            } else { status = location == nil ? .idle : .available }
        case .denied:
            finishRequest()
            location = nil
            status = .denied
        case .restricted:
            finishRequest()
            location = nil
            status = .restricted
        @unknown default:
            unavailable()
        }
    }

    func cancel() {
        finishRequest()
        if isLoading { status = location == nil ? .idle : .available }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        refreshAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard requested else { return }
        let authorization = self.manager.authorizationStatus
        guard authorization == .authorizedWhenInUse || authorization == .authorizedAlways else {
            refreshAuthorization()
            return
        }
        // Ignore invalid fixes and stale cached readings; approximate-location fixes are supported.
        let now = Date()
        guard let latest = locations.reversed().first(where: {
            CLLocationCoordinate2DIsValid($0.coordinate) && $0.horizontalAccuracy.isFinite
                && $0.horizontalAccuracy >= 0 && abs($0.timestamp.timeIntervalSince(now)) <= 120
        }) else {
            unavailable()
            return
        }
        finishRequest()
        location = latest
        status = .available
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard requested else { return }
        if self.manager.authorizationStatus == .denied || self.manager.authorizationStatus == .restricted {
            refreshAuthorization()
        } else { unavailable() }
    }

    private func beginLocationRequest() {
        status = .locating
        timeoutTask?.cancel()
        let timeout = requestTimeout
        timeoutTask = Task { [weak self] in
            do { try await Task.sleep(for: timeout) }
            catch { return }
            guard let self, self.requested, !Task.isCancelled else { return }
            self.unavailable()
        }
        manager.requestLocation()
    }

    private func unavailable() {
        finishRequest()
        location = nil
        status = .unavailable("Location is temporarily unavailable. Try again or select a gym manually.")
    }

    private func finishRequest() {
        requested = false
        timeoutTask?.cancel()
        timeoutTask = nil
        manager.stopUpdatingLocation()
    }

    deinit { timeoutTask?.cancel() }
}
