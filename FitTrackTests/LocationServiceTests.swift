import CoreLocation
import Foundation
import Testing
@testable import FitTrack

@MainActor
struct LocationServiceTests {
    private func fix(latitude: Double = 39.99959, accuracy: Double = 50, age: TimeInterval = 0) -> CLLocation {
        CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: -83.01842),
                   altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: -1,
                   timestamp: Date().addingTimeInterval(-age))
    }

    @Test func permissionIsRequestedOnlyAfterUserActionAndGPSWaitsForAuthorization() {
        let manager = StubLocationManager()
        let service = LocationService(manager: manager)
        #expect(service.authorizationStatus == .notDetermined)
        #expect(service.status == .idle)
        #expect(manager.permissionRequests == 0 && manager.locationRequests == 0)
        service.requestLocation()
        service.requestLocation()
        #expect(service.status == .requestingPermission)
        #expect(manager.permissionRequests == 1 && manager.locationRequests == 0)
        manager.authorizationStatus = .authorizedWhenInUse
        service.refreshAuthorization()
        service.refreshAuthorization()
        #expect(service.status == .locating)
        #expect(manager.locationRequests == 1)
        service.cancel()
    }

    @Test func deniedAndRestrictedPermissionsNeverStartGPSAndCanRecoverAfterSettings() {
        for status in [CLAuthorizationStatus.denied, .restricted] {
            let manager = StubLocationManager()
            manager.authorizationStatus = status
            let service = LocationService(manager: manager)
            service.requestLocation()
            #expect(service.status == (status == .denied ? .denied : .restricted))
            #expect(!service.isLoading && service.location == nil)
            #expect(manager.permissionRequests == 0 && manager.locationRequests == 0)
            manager.authorizationStatus = .authorizedWhenInUse
            service.refreshAuthorization()
            #expect(service.status == .idle)
            #expect(manager.locationRequests == 0)
            service.requestLocation()
            #expect(manager.locationRequests == 1)
            service.cancel()
        }
    }

    @Test func freshApproximateFixIsAcceptedAndPermissionRevocationClearsIt() {
        let manager = StubLocationManager()
        manager.authorizationStatus = .authorizedWhenInUse
        let service = LocationService(manager: manager)
        service.requestLocation()
        service.locationManager(CLLocationManager(), didUpdateLocations: [fix(accuracy: 3000)])
        #expect(service.status == .available)
        #expect(service.location != nil && !service.isLoading)
        manager.authorizationStatus = .denied
        service.refreshAuthorization()
        #expect(service.status == .denied && service.location == nil)
    }

    @Test func invalidStaleAndEmptyFixesDoNotProduceDistances() {
        for locations in [[fix(accuracy: -1)], [fix(age: 300)], [fix(latitude: 100)], []] {
            let manager = StubLocationManager()
            manager.authorizationStatus = .authorizedWhenInUse
            let service = LocationService(manager: manager)
            service.requestLocation()
            service.locationManager(CLLocationManager(), didUpdateLocations: locations)
            #expect(service.location == nil && !service.isLoading)
            if case .unavailable = service.status { } else { Issue.record("Expected unavailable location") }
            #expect(GymDiscovery.ranked(GymCatalog.gyms, from: service.location).allSatisfy { $0.distanceLabel == nil })
        }
    }

    @Test func transientErrorsCanRetryAndCancelledCallbacksAreIgnored() {
        let manager = StubLocationManager()
        manager.authorizationStatus = .authorizedWhenInUse
        let service = LocationService(manager: manager)
        service.requestLocation()
        service.locationManager(CLLocationManager(), didFailWithError: NSError(domain: kCLErrorDomain, code: 0))
        #expect(!service.isLoading && service.location == nil)
        service.requestLocation()
        #expect(manager.locationRequests == 2)
        service.cancel()
        service.locationManager(CLLocationManager(), didUpdateLocations: [fix()])
        service.locationManager(CLLocationManager(), didFailWithError: NSError(domain: kCLErrorDomain, code: 0))
        #expect(service.status == .idle && service.location == nil)
    }

    @Test func revokedPermissionIsCheckedBeforeAcceptingAnInFlightFix() {
        let manager = StubLocationManager()
        manager.authorizationStatus = .authorizedWhenInUse
        let service = LocationService(manager: manager)
        service.requestLocation()
        manager.authorizationStatus = .denied
        service.locationManager(CLLocationManager(), didUpdateLocations: [fix()])
        #expect(service.status == .denied && service.location == nil)
    }

    @Test func stalledLocationRequestTimesOutAndRemainsRetryable() async {
        let manager = StubLocationManager()
        manager.authorizationStatus = .authorizedWhenInUse
        let service = LocationService(manager: manager, requestTimeout: .milliseconds(10))
        service.requestLocation()
        while service.isLoading { await Task.yield() }
        if case .unavailable = service.status { } else { Issue.record("Expected request timeout") }
        #expect(manager.stops > 0 && service.location == nil)
        service.requestLocation()
        #expect(manager.locationRequests == 2)
        service.cancel()
    }
}

@MainActor
private final class StubLocationManager: LocationManaging {
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    weak var delegate: CLLocationManagerDelegate?
    var desiredAccuracy: CLLocationAccuracy = 0
    var permissionRequests = 0
    var locationRequests = 0
    var stops = 0
    func requestWhenInUseAuthorization() { permissionRequests += 1 }
    func requestLocation() { locationRequests += 1 }
    func stopUpdatingLocation() { stops += 1 }
}
