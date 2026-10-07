import Foundation
import Testing
@testable import FitTrack

@MainActor
struct FitTrackTests {
    @Test func advancementRequiresEverySetAndSkipRetainsCompletedSets() {
        var session = WorkoutSession(name: "Test", gymID: "rpac", exercises: WorkoutCatalog.defaultPlan.exercises)
        session.advance()
        #expect(session.currentIndex == 0)
        session.completeSet(session.exercises[0].sets[0].id)
        session.advance(skipping: true)
        #expect(session.currentIndex == 1)
        #expect(session.exercises[0].isSkipped)
        #expect(session.exercises[0].sets[0].isComplete)
        #expect(session.completedCount == 0)
    }

    @Test func replacementMatchesMuscleAndResetsCompletion() {
        var session = WorkoutSession(name: "Test", gymID: "rpac", exercises: WorkoutCatalog.defaultPlan.exercises)
        session.completeSet(session.exercises[0].sets[0].id)
        let original = session.exercises[0]
        let wrongMuscle = WorkoutCatalog.exercises[2]
        session.replaceExercise(with: wrongMuscle)
        #expect(session.exercises[0] == original)
        let alternative = WorkoutCatalog.alternatives(for: original)[0]
        session.replaceExercise(with: alternative)
        #expect(session.exercises[0].exerciseID == alternative.exerciseID)
        #expect(session.exercises[0].id == original.id)
        #expect(session.exercises[0].sets.allSatisfy { !$0.isComplete })
        #expect(session.exercises[0].equipment != original.equipment)
    }

    @Test func editsValidateTargetsAndFinishFreezesSession() {
        var session = WorkoutSession(name: "Test", gymID: "rpac", exercises: [WorkoutCatalog.exercises[0]])
        let original = session.exercises[0].sets
        session.editSets([PlannedSet(weight: -1, reps: 0, rest: -1)])
        #expect(session.exercises[0].sets == original)
        for set in original { session.completeSet(set.id) }
        #expect(session.canAdvance)
        let end = session.startedAt.addingTimeInterval(60)
        session.advance(now: end)
        #expect(session.finishedAt == end)
        let finished = session
        session.completeSet(original[0].id)
        session.advance(skipping: true)
        #expect(session == finished)
    }

    @MainActor @Test func draftRestoresAndStartingAgainDoesNotOverwriteIt() throws {
        let suite = "FitTrackTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WorkoutStore(defaults: defaults, saveRemote: { _, _ in })
        store.startWorkout()
        let session = try #require(store.session)
        store.completeSet(session.exercises[0].sets[0].id)
        store.selectGym("north-recreation")
        store.startWorkout(plan: WorkoutPlan(name: "Other", exercises: [WorkoutCatalog.exercises[2]]))
        #expect(store.session?.id == session.id)
        let restored = WorkoutStore(defaults: defaults, saveRemote: { _, _ in })
        #expect(restored.session == store.session)
        #expect(restored.gymID == "north-recreation")
    }

    @MainActor @Test func failedSaveCanRetryWithSameWorkoutID() async throws {
        let suite = "FitTrackTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var requests: [Workout] = []
        var callback: ((Result<Void, Error>) -> Void)?
        let store = WorkoutStore(defaults: defaults) { workout, completion in
            requests.append(workout)
            callback = completion
        }
        store.startWorkout(plan: WorkoutPlan(name: "Test", exercises: [WorkoutCatalog.exercises[0]]))
        store.skipExercise()
        store.saveWorkout()
        store.saveWorkout()
        #expect(requests.count == 1)
        #expect(requests[0].exercises[0].isSkipped == true)
        callback?(.failure(NSError(domain: "Test", code: 1)))
        while store.isSaving { await Task.yield() }
        #expect(!store.isSaved)
        #expect(store.history.isEmpty)
        store.startWorkout()
        #expect(store.session?.id.uuidString == requests[0].workoutID)
        store.saveWorkout()
        #expect(requests.count == 2)
        #expect(requests[0].workoutID == requests[1].workoutID)
        callback?(.success(()))
        while store.isSaving { await Task.yield() }
        #expect(store.isSaved)
        #expect(store.history.count == 1)
        store.saveWorkout()
        #expect(requests.count == 2)
    }
}
