import Foundation

struct Exercise: Identifiable, Codable {
    var id: String { exerciseID }

    let exerciseID: String
    var name: String
    var muscleGroup: String
    var equipment: String
}
