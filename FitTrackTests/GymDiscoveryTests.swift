import CoreLocation
import Foundation
import Testing
@testable import FitTrack

@MainActor
struct GymDiscoveryTests {
    @Test func selectedGymUsesTheExistingAccountSpecificCache() throws {
        let firstSuite = "GymTests.first.\(UUID())"
        let secondSuite = "GymTests.second.\(UUID())"
        let first = try #require(UserDefaults(suiteName: firstSuite))
        let second = try #require(UserDefaults(suiteName: secondSuite))
        defer {
            first.removePersistentDomain(forName: firstSuite)
            second.removePersistentDomain(forName: secondSuite)
        }
        let store = WorkoutStore(defaults: first, saveRemote: { _, _ in })
        store.selectGym("north-recreation")
        store.selectGym("invalid-gym")
        let restored = WorkoutStore(defaults: first, saveRemote: { _, _ in })
        let otherAccount = WorkoutStore(defaults: second, saveRemote: { _, _ in })
        #expect(restored.gymID == "north-recreation")
        #expect(otherAccount.gymID == "rpac")
        restored.startWorkout()
        #expect(restored.session?.gymID == "north-recreation")
    }

    @Test func manualSelectionKeepsEveryExistingGymAndHasNoInventedDistances() {
        let results = GymDiscovery.ranked(GymCatalog.gyms, from: nil)
        #expect(results.map(\.id) == ["rpac", "north-recreation", "adventure-recreation"])
        #expect(results.allSatisfy { $0.distanceMeters == nil && $0.distanceLabel == nil })
        #expect(Set(results.map(\.id)).count == 3)
        #expect(GymCatalog.gyms.allSatisfy {
            CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude))
        })
    }

    @Test func eachCampusGymIsNearestWhenStandingAtItsCoordinate() {
        for gym in GymCatalog.gyms {
            let location = CLLocation(latitude: gym.latitude, longitude: gym.longitude)
            let results = GymDiscovery.ranked(GymCatalog.gyms, from: location)
            #expect(results.first?.id == gym.id)
            #expect(results.first?.distanceMeters == 0)
            #expect(results.first?.distanceLabel == "<0.1 mi")
            let distances = results.compactMap(\.distanceMeters)
            #expect(distances == distances.sorted())
        }
    }

    @Test func distanceUsesCoreLocationAndConvertsMetersToMiles() throws {
        let gym = GymCatalog.gyms[0]
        let location = CLLocation(latitude: 40.01, longitude: -83.02)
        let result = try #require(GymDiscovery.ranked([gym], from: location).first)
        let expected = location.distance(from: CLLocation(latitude: gym.latitude, longitude: gym.longitude))
        let meters = try #require(result.distanceMeters)
        let miles = try #require(result.distanceMiles)
        #expect(abs(meters - expected) < 0.001)
        #expect(abs(miles - expected / 1609.344) < 0.000001)
        #expect(result.distanceLabel?.hasSuffix(" mi") == true)
    }

    @Test func tiedDistancesKeepStableCatalogOrderAndEmptyCatalogIsSupported() {
        let first = GymCatalog.gyms[0]
        var second = GymCatalog.gyms[1]
        second.latitude = first.latitude
        second.longitude = first.longitude
        let location = CLLocation(latitude: first.latitude, longitude: first.longitude)
        #expect(GymDiscovery.ranked([first, second], from: location).map(\.id) == [first.id, second.id])
        #expect(GymDiscovery.ranked([], from: location).isEmpty)
    }
}
