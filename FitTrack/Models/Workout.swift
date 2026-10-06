import Foundation

struct Workout: Identifiable, Codable {
    var id: String { workoutID }

    let workoutID: String
    let userID: String
    let gymID: String?
    var date: Date
    var duration: Int
    var workoutType: String
    var exercises: [WorkoutExercise]
}
