import Foundation
import Testing
@testable import FitTrack

@MainActor
struct HistoryIntegrationTests {
    private func workout(name: String = "Demo", complete: Bool = true) -> Workout {
        let sets = [PlannedSet(weight: 95, reps: 10, rest: 60, isComplete: true),
                    PlannedSet(weight: 95, reps: 10, rest: 60, isComplete: complete)]
        return Workout(workoutID: "cloud-one", userID: "test-account", gymID: "rpac", gymName: "RPAC",
                       date: Date(), duration: 90, workoutType: name,
                       exercises: [WorkoutExercise(workoutID: "cloud-one", exerciseID: "bench", weight: 95,
                           reps: 10, sets: complete ? 2 : 1, setResults: sets)])
    }

    @Test func refreshDuringReadIsNotLost() async {
        let repository = DelayedHistoryRepository()
        let cloud = SavedWorkoutsStore(repository: repository)
        cloud.load()
        cloud.refresh()
        cloud.refresh()
        #expect(repository.readCount == 1)
        repository.completeRead([])
        while repository.readCount < 2 { await Task.yield() }
        #expect(cloud.isBusy)
        repository.completeRead([workout()])
        while cloud.isBusy { await Task.yield() }
        #expect(repository.readCount == 2)
        #expect(cloud.workouts.map(\.id) == ["cloud-one"])
    }

    @Test func sharedHistoryReflectsCloudRenameAndDelete() async {
        let repository = DelayedHistoryRepository()
        let cloud = SavedWorkoutsStore(repository: repository)
        cloud.load()
        repository.completeRead([workout()])
        while cloud.isBusy { await Task.yield() }
        cloud.rename(workout(), to: "Renamed") { }
        while cloud.isBusy { await Task.yield() }
        let renamed = WorkoutCalendarRecords.snapshot(workouts: cloud.workouts, schedules: [], gyms: GymCatalog.gyms)
        #expect(renamed.records(on: Date()).first?.title == "Renamed")
        cloud.delete(workout())
        while cloud.isBusy { await Task.yield() }
        let deleted = WorkoutCalendarRecords.snapshot(workouts: cloud.workouts, schedules: [], gyms: GymCatalog.gyms)
        #expect(deleted.records(on: Date()).isEmpty)
        #expect(deleted.streak(through: Date()) == 0)
    }

    @Test func finishedUnsavedSessionIsNotCloudHistoryAndSaveCallbackStillWorks() async throws {
        let suite = "HistoryIntegration.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var callback: ((Result<Void, Error>) -> Void)?
        var refreshCount = 0
        let store = WorkoutStore(defaults: defaults, onWorkoutSaved: { refreshCount += 1 }) { _, completion in
            callback = completion
        }
        store.startWorkout(plan: WorkoutPlan(name: "Draft", exercises: [WorkoutCatalog.exercises[0]]))
        store.skipExercise()
        #expect(store.session?.finishedAt != nil)
        #expect(WorkoutCalendarRecords.snapshot(workouts: [], schedules: store.scheduledWorkouts,
            gyms: WorkoutStore.gyms).records(on: Date()).isEmpty)
        store.saveWorkout()
        callback?(.failure(NSError(domain: "Offline", code: 1)))
        while store.isSaving { await Task.yield() }
        #expect(refreshCount == 0 && store.history.isEmpty)
        store.saveWorkout()
        callback?(.success(()))
        while store.isSaving { await Task.yield() }
        #expect(refreshCount == 1 && store.history.count == 1)
        // A removed cloud document must not reappear through the retained legacy cache.
        #expect(WorkoutCalendarRecords.snapshot(workouts: [], schedules: [], gyms: WorkoutStore.gyms)
            .records(on: Date()).isEmpty)
    }

    @Test func partialRemoteSetsDoNotCountAsCompletedExercise() {
        let records = WorkoutCalendarRecords.saved(workouts: [workout(complete: false)], calendar: .current)
        #expect(records.first?.status == .partial)
        #expect(records.first?.completed == 0)
        let completed = WorkoutCalendarRecords.saved(workouts: [workout()], calendar: .current)
        #expect(completed.first?.status == .complete)
        #expect(completed.first?.completed == 1)
    }

    @Test func homeAndCalendarShareCloudAndRestDayStreakRules() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let earlier = calendar.date(byAdding: .day, value: -2, to: today)!
        var first = workout()
        first.date = today
        var second = workout(name: "Earlier")
        second = Workout(workoutID: "cloud-two", userID: second.userID, gymID: second.gymID,
                         date: earlier, duration: second.duration, workoutType: second.workoutType, exercises: second.exercises)
        let rest = ScheduledWorkout(day: calendar.dateComponents([.year, .month, .day], from: yesterday), plan: nil, gymID: "rpac")
        let snapshot = WorkoutCalendarRecords.snapshot(workouts: [first, second], schedules: [rest],
                                                      gyms: GymCatalog.gyms, calendar: calendar)
        #expect(snapshot.streak(through: today) == 2)
        #expect(snapshot.status(on: yesterday) == .rest)
    }
}

@MainActor
private final class DelayedHistoryRepository: SavedWorkoutRepository {
    var readCount = 0
    private var read: ((Result<[Workout], Error>) -> Void)?
    func fetchWorkouts(completion: @escaping (Result<[Workout], Error>) -> Void) {
        readCount += 1
        read = completion
    }
    func completeRead(_ workouts: [Workout]) {
        let callback = read
        read = nil
        callback?(.success(workouts))
    }
    func updateWorkout(_ workout: Workout, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func deleteWorkout(id: String, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}
