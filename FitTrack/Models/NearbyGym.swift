import CoreLocation
import Foundation

struct NearbyGym: Identifiable {
    var id: String { gym.id }
    let gym: Gym
    let distanceMeters: CLLocationDistance?

    var distanceMiles: Double? { distanceMeters.map { $0 / 1609.344 } }
    var distanceLabel: String? {
        guard let miles = distanceMiles else { return nil }
        return miles < 0.1 ? "<0.1 mi" : "\(miles.formatted(.number.precision(.fractionLength(1)))) mi"
    }
}

enum GymDiscovery {
    /// Straight-line distances, not travel distances. Without GPS, keep the manual catalog order.
    static func ranked(_ gyms: [Gym], from location: CLLocation?) -> [NearbyGym] {
        guard let location else { return gyms.map { NearbyGym(gym: $0, distanceMeters: nil) } }
        return gyms.enumerated().map { index, gym in
            (index, NearbyGym(gym: gym, distanceMeters: location.distance(from:
                CLLocation(latitude: gym.latitude, longitude: gym.longitude))))
        }.sorted { lhs, rhs in
            let left = lhs.1.distanceMeters ?? .infinity
            let right = rhs.1.distanceMeters ?? .infinity
            return left == right ? lhs.0 < rhs.0 : left < right
        }.map(\.1)
    }
}
