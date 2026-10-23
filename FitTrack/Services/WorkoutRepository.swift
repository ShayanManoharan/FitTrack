import FirebaseFirestore
import Foundation

enum WorkoutRepositoryError: LocalizedError {
    case unauthenticated
    case invalidDocument

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "Sign in before accessing workouts."
        case .invalidDocument:
            return "The Firestore workout document is invalid."
        }
    }
}

protocol SavedWorkoutRepository {
    func fetchWorkouts(completion: @escaping (Result<[Workout], Error>) -> Void)
    func updateWorkout(_ workout: Workout, completion: @escaping (Result<Void, Error>) -> Void)
    func deleteWorkout(id: String, completion: @escaping (Result<Void, Error>) -> Void)
}

final class WorkoutRepository: SavedWorkoutRepository {
    private let db: Firestore
    private let authRepository: AuthRepository

    init(db: Firestore = Firestore.firestore(), authRepository: AuthRepository = AuthRepository()) {
        self.db = db
        self.authRepository = authRepository
    }

    func createWorkout(
        _ workout: Workout,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        write(workout, merge: false, completion: completion)
    }

    func fetchWorkout(
        id: String,
        completion: @escaping (Result<Workout, Error>) -> Void
    ) {
        guard let reference = workoutReference(id: id) else {
            completion(.failure(WorkoutRepositoryError.unauthenticated))
            return
        }
        reference.getDocument { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                completion(.failure(error))
                return
            }
            guard let snapshot, let workout = self.decode(snapshot.data(), id: snapshot.documentID) else {
                completion(.failure(WorkoutRepositoryError.invalidDocument))
                return
            }
            completion(.success(workout))
        }
    }

    func fetchWorkouts(
        completion: @escaping (Result<[Workout], Error>) -> Void
    ) {
        guard let collection = workoutsCollection() else {
            completion(.failure(WorkoutRepositoryError.unauthenticated))
            return
        }
        collection
            .order(by: "date", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    completion(.failure(error))
                    return
                }
                let workouts = snapshot?.documents.compactMap {
                    self.decode($0.data(), id: $0.documentID)
                } ?? []
                completion(.success(workouts))
            }
    }

    func updateWorkout(
        _ workout: Workout,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        write(workout, merge: true, completion: completion)
    }

    func deleteWorkout(
        id: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let reference = workoutReference(id: id) else {
            completion(.failure(WorkoutRepositoryError.unauthenticated))
            return
        }
        reference.delete { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    private func write(
        _ workout: Workout,
        merge: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let reference = workoutReference(id: workout.workoutID) else {
            completion(.failure(WorkoutRepositoryError.unauthenticated))
            return
        }
        reference.setData(
            data(for: workout),
            merge: merge
        ) { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    private func workoutsCollection() -> CollectionReference? {
        guard let userID = authRepository.currentUser?.id else { return nil }
        return db.collection("users")
            .document(userID)
            .collection("workouts")
    }

    private func workoutReference(id: String) -> DocumentReference? {
        workoutsCollection()?.document(id)
    }

    private func data(for workout: Workout) -> [String: Any] {
        var data: [String: Any] = [
            "workoutID": workout.workoutID,
            "userID": workout.userID,
            "date": Timestamp(date: workout.date),
            "duration": workout.duration,
            "workoutType": workout.workoutType,
            "exercises": workout.exercises.map { exercise in
                var data: [String: Any] = [
                    "workoutID": exercise.workoutID,
                    "exerciseID": exercise.exerciseID,
                    "weight": exercise.weight,
                    "reps": exercise.reps,
                    "sets": exercise.sets,
                    "isSkipped": exercise.isSkipped ?? false,
                    "setResults": (exercise.setResults ?? []).map { set in
                        [
                            "weight": set.weight,
                            "reps": set.reps,
                            "rest": set.rest,
                            "isComplete": set.isComplete
                        ]
                    }
                ]
                if let name = exercise.name { data["name"] = name }
                if let muscleGroup = exercise.muscleGroup { data["muscleGroup"] = muscleGroup }
                if let equipment = exercise.equipment { data["equipment"] = equipment }
                return data
            }
        ]
        if let gymID = workout.gymID { data["gymID"] = gymID }
        if let gymName = workout.gymName { data["gymName"] = gymName }
        return data
    }

    private func decode(_ data: [String: Any]?, id: String) -> Workout? {
        guard let data,
              let userID = data["userID"] as? String,
              let duration = data["duration"] as? Int,
              let workoutType = data["workoutType"] as? String,
              let exercisesData = data["exercises"] as? [[String: Any]] else {
            return nil
        }
        let date = (data["date"] as? Timestamp)?.dateValue() ?? data["date"] as? Date ?? Date()
        let exercises = exercisesData.compactMap(decodeExercise)
        return Workout(
            workoutID: id,
            userID: userID,
            gymID: data["gymID"] as? String,
            gymName: data["gymName"] as? String,
            date: date,
            duration: duration,
            workoutType: workoutType,
            exercises: exercises
        )
    }

    private func decodeExercise(_ data: [String: Any]) -> WorkoutExercise? {
        guard let workoutID = data["workoutID"] as? String,
              let exerciseID = data["exerciseID"] as? String,
              let weight = data["weight"] as? Double,
              let reps = data["reps"] as? Int,
              let sets = data["sets"] as? Int else {
            return nil
        }
        let setResults: [PlannedSet]? = (data["setResults"] as? [[String: Any]])?.compactMap { set -> PlannedSet? in
            guard let weight = set["weight"] as? Double,
                  let reps = set["reps"] as? Int,
                  let rest = set["rest"] as? Int,
                  let isComplete = set["isComplete"] as? Bool else {
                return nil
            }
            return PlannedSet(weight: weight, reps: reps, rest: rest, isComplete: isComplete)
        }
        return WorkoutExercise(
            workoutID: workoutID,
            exerciseID: exerciseID,
            weight: weight,
            reps: reps,
            sets: sets,
            name: data["name"] as? String,
            muscleGroup: data["muscleGroup"] as? String,
            equipment: data["equipment"] as? String,
            setResults: setResults,
            isSkipped: data["isSkipped"] as? Bool
        )
    }
}
