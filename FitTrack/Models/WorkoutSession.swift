import Foundation

struct PlannedSet: Identifiable, Codable, Equatable {
    var id = UUID()
    var weight: Double
    var reps: Int
    var rest: Int
    var isComplete = false
}

struct SessionExercise: Identifiable, Codable, Equatable {
    var id = UUID()
    var exerciseID: String
    var name: String
    var muscleGroup: String
    var equipment: String
    var sets: [PlannedSet]
    var isSkipped = false
    var isComplete: Bool { !isSkipped && !sets.isEmpty && sets.allSatisfy(\.isComplete) }
}

struct WorkoutPlan: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var exercises: [SessionExercise]
}

struct WorkoutSession: Codable, Equatable {
    var id = UUID()
    var name: String
    var startedAt = Date()
    var finishedAt: Date?
    var gymID: String
    var exercises: [SessionExercise]
    var currentIndex = 0
    var completedCount: Int { exercises.filter(\.isComplete).count }
    var currentExercise: SessionExercise? {
        exercises.indices.contains(currentIndex) ? exercises[currentIndex] : nil
    }
    var canAdvance: Bool { finishedAt == nil && currentExercise?.isComplete == true }

    mutating func completeSet(_ setID: UUID) {
        guard finishedAt == nil, exercises.indices.contains(currentIndex),
              let index = exercises[currentIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        exercises[currentIndex].sets[index].isComplete.toggle()
    }

    mutating func replaceExercise(with alternative: SessionExercise) {
        guard finishedAt == nil, exercises.indices.contains(currentIndex),
              alternative.muscleGroup == exercises[currentIndex].muscleGroup,
              alternative.equipment != exercises[currentIndex].equipment else { return }
        var replacement = alternative
        // A replacement has its own suggested targets and starts unchecked.
        replacement.id = exercises[currentIndex].id
        replacement.sets = replacement.sets.map { set in
            var target = set
            target.isComplete = false
            return target
        }
        exercises[currentIndex] = replacement
    }

    mutating func editSets(_ targets: [PlannedSet]) {
        guard finishedAt == nil, exercises.indices.contains(currentIndex), !targets.isEmpty,
              targets.allSatisfy({ $0.weight.isFinite && $0.weight >= 0 && $0.reps > 0 && $0.rest >= 0 }) else { return }
        exercises[currentIndex].sets = targets
    }

    mutating func advance(skipping: Bool = false, now: Date = Date()) {
        guard finishedAt == nil, exercises.indices.contains(currentIndex), skipping || canAdvance else { return }
        if skipping { exercises[currentIndex].isSkipped = true }
        if currentIndex + 1 < exercises.count { currentIndex += 1 }
        else { finishedAt = now }
    }
}

enum WorkoutCatalog {
    static func exercise(_ id: String, _ name: String, _ muscle: String, _ equipment: String,
                         _ weight: Double, _ reps: Int, _ rest: Int) -> SessionExercise {
        SessionExercise(exerciseID: id, name: name, muscleGroup: muscle, equipment: equipment,
                        sets: (0..<3).map { _ in PlannedSet(weight: weight, reps: reps, rest: rest) })
    }

    static var exercises: [SessionExercise] { [
        exercise("barbell-bench-press", "Bench Press", "Chest", "Barbell", 95, 10, 90),
        exercise("incline-dumbbell-press", "Incline Dumbbell Press", "Chest", "Dumbbells", 35, 10, 90),
        exercise("seated-cable-row", "Seated Cable Row", "Back", "Cable", 80, 12, 75),
        exercise("dumbbell-shoulder-press", "Shoulder Press", "Shoulders", "Dumbbells", 30, 10, 90),
        exercise("triceps-pushdown", "Triceps Pushdown", "Arms", "Cable", 40, 12, 60),
        exercise("squat", "Squat", "Legs", "Barbell", 95, 10, 90),
        exercise("deadlift", "Deadlift", "Back", "Barbell", 95, 8, 90),
        exercise("dumbbell-bench-press", "Dumbbell Bench Press", "Chest", "Dumbbells", 35, 10, 90),
        exercise("chest-press-machine", "Chest Press Machine", "Chest", "Machine", 70, 10, 90),
        exercise("push-ups", "Push-ups", "Chest", "Bodyweight", 0, 10, 60),
        exercise("dumbbell-row", "Dumbbell Row", "Back", "Dumbbells", 30, 12, 75),
        exercise("assisted-pull-up", "Assisted Pull-up", "Back", "Machine", 0, 10, 75),
        exercise("machine-shoulder-press", "Machine Shoulder Press", "Shoulders", "Machine", 40, 10, 90),
        exercise("barbell-overhead-press", "Barbell Overhead Press", "Shoulders", "Barbell", 45, 10, 90),
        exercise("dumbbell-triceps-extension", "Dumbbell Triceps Extension", "Arms", "Dumbbells", 20, 12, 60),
        exercise("close-grip-push-up", "Close-grip Push-up", "Arms", "Bodyweight", 0, 12, 60),
        exercise("goblet-squat", "Goblet Squat", "Legs", "Dumbbells", 30, 10, 90),
        exercise("bodyweight-squat", "Bodyweight Squat", "Legs", "Bodyweight", 0, 15, 60)
    ] }
    static var defaultPlan: WorkoutPlan { WorkoutPlan(name: "Upper Body Strength", exercises: Array(exercises.prefix(5))) }
    static func alternatives(for exercise: SessionExercise) -> [SessionExercise] {
        Array(exercises.filter { $0.muscleGroup == exercise.muscleGroup && $0.equipment != exercise.equipment }.prefix(3))
    }
}
