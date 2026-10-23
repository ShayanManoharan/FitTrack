import Foundation
import Testing
@testable import FitTrack

@MainActor
struct SavedWorkoutsStoreTests {
    private func workout(_ id: String = "saved-one") -> Workout {
        Workout(workoutID: id, userID: "account-one", gymID: "rpac", gymName: "RPAC",
                date: Date(), duration: 60, workoutType: "Original",
                exercises: [WorkoutExercise(workoutID: id, exerciseID: "bench", weight: 95, reps: 10, sets: 3)])
    }

    @Test func readRetriesAfterFailureAndIgnoresOverlappingRequests() async {
        let repository = StubSavedWorkoutRepository()
        repository.readResult = .failure(NSError(domain: "Offline", code: 1))
        let store = SavedWorkoutsStore(repository: repository)
        store.load()
        store.load()
        #expect(repository.readCount == 1)
        while store.isBusy { await Task.yield() }
        #expect(store.errorMessage != nil)
        repository.readResult = .success([workout()])
        store.load()
        while store.isBusy { await Task.yield() }
        #expect(store.workouts.map(\.id) == ["saved-one"])
        #expect(store.errorMessage == nil)
    }

    @Test func renameKeepsDocumentIdentityAndOtherWorkoutFields() async throws {
        let repository = StubSavedWorkoutRepository()
        let original = workout()
        repository.readResult = .success([original])
        let store = SavedWorkoutsStore(repository: repository)
        store.load()
        while store.isBusy { await Task.yield() }
        var dismissed = false
        store.rename(original, to: "  Renamed  ") { dismissed = true }
        #expect(!dismissed)
        while store.isBusy { await Task.yield() }
        let sent = try #require(repository.updated)
        #expect(sent.workoutType == "Renamed")
        #expect(sent.id == original.id)
        #expect(sent.userID == original.userID)
        #expect(sent.gymID == original.gymID)
        #expect(sent.exercises.first?.weight == 95)
        #expect(store.workouts.first?.workoutType == "Renamed")
        #expect(dismissed)
        repository.updated = nil
        store.rename(original, to: "   ") { }
        #expect(repository.updated == nil)
    }

    @Test func failedRenameDoesNotReplaceDisplayedWorkout() async {
        let repository = StubSavedWorkoutRepository()
        repository.readResult = .success([workout()])
        repository.writeResult = .failure(NSError(domain: "Permission", code: 1))
        let store = SavedWorkoutsStore(repository: repository)
        store.load()
        while store.isBusy { await Task.yield() }
        var dismissed = false
        store.rename(workout(), to: "New") { dismissed = true }
        while store.isBusy { await Task.yield() }
        #expect(store.workouts.first?.workoutType == "Original")
        #expect(store.errorMessage != nil)
        #expect(!dismissed)
    }

    @Test func deleteOnlyRemovesTheSelectedRecordAfterServerSuccess() async {
        let repository = StubSavedWorkoutRepository()
        repository.readResult = .success([workout(), workout("saved-two")])
        repository.writeResult = .failure(NSError(domain: "Offline", code: 1))
        let store = SavedWorkoutsStore(repository: repository)
        store.load()
        while store.isBusy { await Task.yield() }
        store.delete(workout())
        while store.isBusy { await Task.yield() }
        #expect(store.workouts.count == 2)
        #expect(store.errorMessage != nil)
        repository.writeResult = .success(())
        store.delete(workout())
        while store.isBusy { await Task.yield() }
        #expect(repository.deletedID == "saved-one")
        #expect(store.workouts.map(\.id) == ["saved-two"])
        #expect(store.errorMessage == nil)
    }

    @Test func finishedWorkoutKeepsItsGymWhenHomeSelectionChanges() throws {
        let suite = "FitTrackGymTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var saved: Workout?
        let store = WorkoutStore(defaults: defaults) { workout, _ in saved = workout }
        store.startWorkout(plan: WorkoutPlan(name: "Test", exercises: [WorkoutCatalog.exercises[0]]))
        store.skipExercise()
        store.selectGym("north-recreation")
        store.saveWorkout()
        #expect(saved?.gymID == "rpac")
        #expect(saved?.gymName == "RPAC")
    }
}

@MainActor
private final class StubSavedWorkoutRepository: SavedWorkoutRepository {
    var readResult: Result<[Workout], Error> = .success([])
    var writeResult: Result<Void, Error> = .success(())
    var readCount = 0
    var updated: Workout?
    var deletedID: String?

    func fetchWorkouts(completion: @escaping (Result<[Workout], Error>) -> Void) {
        readCount += 1
        completion(readResult)
    }
    func updateWorkout(_ workout: Workout, completion: @escaping (Result<Void, Error>) -> Void) {
        updated = workout
        completion(writeResult)
    }
    func deleteWorkout(id: String, completion: @escaping (Result<Void, Error>) -> Void) {
        deletedID = id
        completion(writeResult)
    }
}
