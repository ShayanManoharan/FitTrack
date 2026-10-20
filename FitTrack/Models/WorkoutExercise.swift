import Foundation

struct WorkoutExercise: Identifiable, Codable {
    var id: String { exerciseID }

    let workoutID: String
    let exerciseID: String
    var weight: Double
    var reps: Int
    var sets: Int
    var name: String? = nil
    var muscleGroup: String? = nil
    var equipment: String? = nil
    var setResults: [PlannedSet]? = nil
    var isSkipped: Bool? = nil
}
