import Foundation
class FirestoreService {
    private let repository: WorkoutRepository

    init(repository: WorkoutRepository = WorkoutRepository()) {
        self.repository = repository
    }
    
    func saveWorkout(
        _ workout: Workout,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        repository.createWorkout(workout, completion: completion)
    }
}
