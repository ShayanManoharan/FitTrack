import Foundation
import Combine

@MainActor
final class WorkoutStore: ObservableObject {
    @Published private(set) var session: WorkoutSession?
    @Published private(set) var plans: [WorkoutPlan] = []
    @Published private(set) var gymID = "rpac"
    @Published private(set) var history: [WorkoutSession] = []
    @Published private(set) var isSaving = false
    @Published private(set) var saveMessage: String?
    @Published private(set) var isSaved = false
    @Published private(set) var storageMessage: String?
    private let defaults: UserDefaults
    private let saveRemote: @MainActor (Workout, @escaping (Result<Void, Error>) -> Void) -> Void

    static let gyms = [(id: "rpac", name: "RPAC"),
                       (id: "north-recreation", name: "North Recreation Center"),
                       (id: "adventure-recreation", name: "Adventure Recreation Center")]
    var gymName: String { Self.gyms.first { $0.id == gymID }?.name ?? "RPAC" }
    var todayPlan: WorkoutPlan { plans.first ?? WorkoutCatalog.defaultPlan }
    var hasActiveSession: Bool { session != nil && session?.finishedAt == nil }
    var hasPendingSession: Bool { session != nil && !isSaved }
    var streak: Int {
        let calendar = Calendar.current
        let days = Set(history.filter { $0.completedCount == $0.exercises.count }
            .map { calendar.startOfDay(for: $0.finishedAt ?? $0.startedAt) })
        var date = calendar.startOfDay(for: Date())
        if !days.contains(date) { date = calendar.date(byAdding: .day, value: -1, to: date)! }
        var count = 0
        while days.contains(date) {
            count += 1
            date = calendar.date(byAdding: .day, value: -1, to: date)!
        }
        return count
    }

    init(defaults: UserDefaults = .standard,
         saveRemote: @escaping @MainActor (Workout, @escaping (Result<Void, Error>) -> Void) -> Void = { workout, completion in
             FirestoreService().saveWorkout(workout, completion: completion)
         }) {
        self.defaults = defaults
        self.saveRemote = saveRemote
        if let data = defaults.data(forKey: "fittrack.native.state") {
            do {
                let state = try JSONDecoder().decode(Cache.self, from: data)
                session = state.session
                plans = state.plans
                history = state.history
                gymID = state.gymID
                isSaved = state.isSaved
            } catch { storageMessage = "Saved local data could not be read. \(error.localizedDescription)" }
        }
    }

    func startWorkout(plan: WorkoutPlan? = nil) {
        guard !hasPendingSession, !isSaving else { return }
        let plan = plan ?? todayPlan
        guard !plan.exercises.isEmpty else { return }
        session = WorkoutSession(name: plan.name, gymID: gymID, exercises: plan.exercises.map { exercise in
            var copy = exercise
            copy.id = UUID()
            copy.isSkipped = false
            copy.sets = copy.sets.map { target in
                var copy = target
                copy.id = UUID()
                copy.isComplete = false
                return copy
            }
            return copy
        })
        isSaved = false
        saveMessage = nil
        persist()
    }

    func completeSet(_ id: UUID) { session?.completeSet(id); persist() }
    func replaceExercise(with alternative: SessionExercise) { session?.replaceExercise(with: alternative); persist() }
    func editSets(_ targets: [PlannedSet]) { session?.editSets(targets); persist() }
    func advanceExercise() { session?.advance(); persist() }
    func skipExercise() { session?.advance(skipping: true); persist() }
    func selectGym(_ id: String) {
        guard Self.gyms.contains(where: { $0.id == id }) else { return }
        gymID = id
        if hasActiveSession { session?.gymID = id }
        persist()
    }
    func savePlan(_ plan: WorkoutPlan) {
        guard !plan.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !plan.exercises.isEmpty else { return }
        if let index = plans.firstIndex(where: { $0.id == plan.id }) { plans[index] = plan }
        else { plans.append(plan) }
        persist()
    }
    func deletePlan(_ id: UUID) { plans.removeAll { $0.id == id }; persist() }

    func saveWorkout() {
        guard let session, let end = session.finishedAt, !isSaving, !isSaved else { return }
        isSaving = true
        saveMessage = nil
        let id = session.id.uuidString
        let workout = Workout(workoutID: id, userID: "demo-user", gymID: session.gymID,
                              date: end, duration: max(0, Int(end.timeIntervalSince(session.startedAt))),
                              workoutType: session.name, exercises: session.exercises.map { exercise in
            WorkoutExercise(workoutID: id, exerciseID: exercise.exerciseID,
                            weight: exercise.sets.first?.weight ?? 0,
                            reps: exercise.sets.first?.reps ?? 0,
                            sets: exercise.sets.filter(\.isComplete).count,
                            setResults: exercise.sets, isSkipped: exercise.isSkipped)
        })
        saveRemote(workout) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isSaving = false
                switch result {
                case .success:
                    self.isSaved = true
                    self.saveMessage = "Workout saved."
                    if !self.history.contains(where: { $0.id == session.id }) { self.history.append(session) }
                    self.persist()
                case .failure(let error):
                    self.saveMessage = "Could not save workout: \(error.localizedDescription). Your workout remains on this device; try again."
                }
            }
        }
    }

    private struct Cache: Codable {
        var session: WorkoutSession?
        var plans: [WorkoutPlan]
        var history: [WorkoutSession]
        var gymID: String
        var isSaved: Bool
    }
    func persist() {
        do {
            let data = try JSONEncoder().encode(Cache(session: session, plans: plans, history: history,
                                                     gymID: gymID, isSaved: isSaved))
            defaults.set(data, forKey: "fittrack.native.state")
            storageMessage = nil
        } catch { storageMessage = "Could not save local progress: \(error.localizedDescription)" }
    }
}
