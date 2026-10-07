import Foundation
import FirebaseFirestore

class FirestoreService {
    
    private let db = Firestore.firestore()
    
    func saveWorkout(
        _ workout: Workout,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var data: [String: Any] = [
            "userID": workout.userID,
            "date": Timestamp(date: workout.date),
            "duration": workout.duration,
            "workoutType": workout.workoutType,
            "exercises": workout.exercises.map { exercise in
                [
                    "workoutID": exercise.workoutID,
                    "exerciseID": exercise.exerciseID,
                    "weight": exercise.weight,
                    "reps": exercise.reps,
                    "sets": exercise.sets,
                    "isSkipped": exercise.isSkipped ?? false,
                    "setResults": (exercise.setResults ?? []).map { set in
                        ["weight": set.weight, "reps": set.reps, "rest": set.rest,
                         "isComplete": set.isComplete] as [String: Any]
                    }
                ]
            }
        ]

        if let gymID = workout.gymID {
            data["gymID"] = gymID
        }

        db.collection("workouts")
            .document(workout.workoutID)
            .setData(data) { error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
    }
}
