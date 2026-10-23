import Combine
import Foundation

/// State for the existing repository's cloud read, update, and delete operations.
@MainActor
final class SavedWorkoutsStore: ObservableObject {
    @Published private(set) var workouts: [Workout] = []
    @Published private(set) var isBusy = false
    @Published private(set) var errorMessage: String?
    private let repository: any SavedWorkoutRepository

    init(repository: any SavedWorkoutRepository = WorkoutRepository()) {
        self.repository = repository
    }

    func load() {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        repository.fetchWorkouts { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isBusy = false
                switch result {
                case .success(let workouts): self.workouts = workouts
                case .failure(let error): self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func rename(_ workout: Workout, to name: String, onSuccess: @escaping () -> Void) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isBusy else { return }
        guard !name.isEmpty, name.count <= 50 else {
            errorMessage = "Use a workout name between 1 and 50 characters."
            return
        }
        var updated = workout
        updated.workoutType = name
        isBusy = true
        errorMessage = nil
        repository.updateWorkout(updated) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isBusy = false
                switch result {
                case .success:
                    if let index = self.workouts.firstIndex(where: { $0.id == updated.id }) {
                        self.workouts[index] = updated
                    }
                    onSuccess()
                case .failure(let error): self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func delete(_ workout: Workout) {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        repository.deleteWorkout(id: workout.id) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isBusy = false
                switch result {
                case .success: self.workouts.removeAll { $0.id == workout.id }
                case .failure(let error): self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
