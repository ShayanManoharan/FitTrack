import Foundation

struct Gym: Identifiable, Codable {
    var id: String { gymID }

    let gymID: String
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
}
