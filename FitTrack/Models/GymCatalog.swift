import Foundation

/// The existing three campus gyms, with approximate building-center coordinates.
/// Addresses: https://recsports.osu.edu/fms/facilities
/// Coordinate data © OpenStreetMap contributors (https://www.openstreetmap.org/copyright), via:
/// https://mapcarta.com/W48208477, https://mapcarta.com/W454962355, https://mapcarta.com/W154204831
enum GymCatalog {
    static let gyms: [Gym] = [
        Gym(gymID: "rpac", name: "RPAC", address: "337 Annie & John Glenn Avenue, Columbus, OH",
            latitude: 39.99959, longitude: -83.01842),
        Gym(gymID: "north-recreation", name: "North Recreation Center", address: "149 W. Lane Avenue, Columbus, OH",
            latitude: 40.00528, longitude: -83.01278),
        Gym(gymID: "adventure-recreation", name: "Adventure Recreation Center", address: "855 Woody Hayes Drive, Columbus, OH",
            latitude: 40.00264, longitude: -83.03190)
    ]
}
