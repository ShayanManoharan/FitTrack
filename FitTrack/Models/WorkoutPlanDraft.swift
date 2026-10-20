import Foundation

/// A detached editor copy. Cancel never changes the saved plan.
struct WorkoutPlanDraft {
    let id: UUID
    var name: String
    var exercises: [SessionExercise]

    init(plan: WorkoutPlan? = nil) {
        id = plan?.id ?? UUID()
        name = plan?.name ?? ""
        exercises = plan?.exercises ?? []
    }

    var validationMessage: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter a workout name."
        }
        if name.count > 50 { return "Use 50 characters or fewer for the workout name." }
        if exercises.isEmpty { return "Choose at least one exercise." }
        if exercises.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return "Enter a name for each custom exercise, or remove it."
        }
        if exercises.contains(where: { $0.name.count > 50 }) {
            return "Use 50 characters or fewer for each exercise name."
        }
        let names = exercises.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        if Set(names).count != names.count { return "Each exercise should appear only once." }
        return nil
    }

    mutating func toggle(_ exercise: SessionExercise) {
        if exercises.contains(where: { $0.exerciseID == exercise.exerciseID }) {
            exercises.removeAll { $0.exerciseID == exercise.exerciseID }
        } else { exercises.append(exercise) }
    }

    mutating func addCustomExercise(named name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        exercises.append(WorkoutCatalog.exercise("custom-\(UUID().uuidString)", name, "Custom", "Unspecified", 0, 10, 60))
    }

    func makePlan() -> WorkoutPlan? {
        guard validationMessage == nil else { return nil }
        return WorkoutPlan(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                           exercises: exercises.map { exercise in
            var result = exercise
            result.name = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return result
        })
    }
}
