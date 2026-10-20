import Foundation
import Testing
@testable import FitTrack

@MainActor
struct WorkoutPlanDraftTests {
    @Test func requiresNameAndExercises() {
        var draft = WorkoutPlanDraft()
        #expect(draft.makePlan() == nil)
        draft.name = "Push Day"
        #expect(draft.makePlan() == nil)
        draft.toggle(WorkoutCatalog.exercises[0])
        #expect(draft.makePlan() != nil)
        draft.name = "   "
        #expect(draft.makePlan() == nil)
    }

    @Test func editingPreservesExistingExercisesAndTargets() throws {
        var plan = WorkoutCatalog.defaultPlan
        plan.exercises[0].sets[0].weight = 135
        plan.exercises.append(WorkoutCatalog.exercise("custom-one", "Custom One", "Custom", "Unspecified", 0, 12, 60))
        plan.exercises.append(WorkoutCatalog.exercise("custom-two", "Custom Two", "Custom", "Unspecified", 0, 8, 90))
        var draft = WorkoutPlanDraft(plan: plan)
        draft.name = "  Updated name  "
        let updated = try #require(draft.makePlan())
        #expect(updated.id == plan.id)
        #expect(updated.name == "Updated name")
        #expect(updated.exercises == plan.exercises)
    }

    @Test func cancelLeavesOriginalUnchanged() {
        let original = WorkoutCatalog.defaultPlan
        var draft = WorkoutPlanDraft(plan: original)
        draft.name = "Unsaved edits"
        draft.exercises.removeAll()
        #expect(original.name == "Upper Body Strength")
        #expect(original.exercises.count == 5)
    }

    @Test func customExercisesCanBeAddedEditedAndRemoved() throws {
        var draft = WorkoutPlanDraft()
        draft.name = "Custom plan"
        draft.addCustomExercise(named: "First")
        draft.addCustomExercise(named: "Second")
        #expect(draft.exercises.count == 2)
        draft.exercises[0].name = "Renamed"
        draft.exercises.removeLast()
        let plan = try #require(draft.makePlan())
        #expect(plan.exercises.map(\.name) == ["Renamed"])
    }

    @Test func rejectsDuplicateAndBlankExerciseNames() {
        var draft = WorkoutPlanDraft()
        draft.name = "Push Day"
        draft.toggle(WorkoutCatalog.exercises[0])
        draft.addCustomExercise(named: " bench press ")
        #expect(draft.makePlan() == nil)
        draft.exercises[1].name = "Different exercise"
        #expect(draft.makePlan() != nil)
        draft.exercises[1].name = "  "
        #expect(draft.makePlan() == nil)
    }
}
