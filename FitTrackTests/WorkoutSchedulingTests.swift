import Foundation
import Testing
@testable import FitTrack

@MainActor
struct WorkoutSchedulingTests {
    @Test func schedulingUpdatesAndRestoresWithoutDuplicatingDates() throws {
        let suite = "SchedulingTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WorkoutStore(defaults: defaults, saveRemote: { _, _ in })
        let first = WorkoutCatalog.defaultPlan
        let second = WorkoutPlan(name: "Leg Day", exercises: [WorkoutCatalog.exercises[5]])
        store.savePlan(first)
        store.savePlan(second)
        let future = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        #expect(store.scheduleWorkout(planID: first.id, on: future))
        #expect(store.scheduleWorkout(planID: second.id, on: future))
        #expect(store.scheduledWorkouts.count == 1)
        #expect(store.scheduledWorkout(on: future)?.plan?.id == second.id)
        let restored = WorkoutStore(defaults: defaults, saveRemote: { _, _ in })
        #expect(restored.scheduledWorkouts == store.scheduledWorkouts)
        store.deletePlan(second.id)
        #expect(store.scheduledWorkout(on: future)?.plan?.name == "Leg Day")
        store.removeScheduledWorkout(store.scheduledWorkouts[0].id)
        #expect(store.scheduledWorkouts.isEmpty)
        #expect(store.plans.count == 1)
    }

    @Test func rejectsPastDatesAndMissingPlans() throws {
        let suite = "SchedulingTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WorkoutStore(defaults: defaults, saveRemote: { _, _ in })
        let plan = WorkoutCatalog.defaultPlan
        store.savePlan(plan)
        let past = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        #expect(!store.scheduleWorkout(planID: plan.id, on: past))
        #expect(!store.scheduleWorkout(planID: UUID(), on: Date()))
        #expect(store.scheduledWorkouts.isEmpty)
    }

    @Test func restDaysPersistAndCanBeReplacedWithWorkouts() throws {
        let suite = "RestDayTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WorkoutStore(defaults: defaults, saveRemote: { _, _ in })
        let future = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        #expect(store.scheduleRestDay(on: future))
        #expect(store.scheduledWorkout(on: future)?.isRestDay == true)
        let restored = WorkoutStore(defaults: defaults, saveRemote: { _, _ in })
        #expect(restored.scheduledWorkout(on: future)?.isRestDay == true)
        let records = WorkoutCalendarRecords.scheduled(store.scheduledWorkouts, excluding: [], gymNames: [:], calendar: Calendar(identifier: .gregorian))
        #expect(records.first?.status == .rest)
        #expect(records.first?.location == nil)
        #expect(records.first?.total == nil)
        let plan = WorkoutCatalog.defaultPlan
        store.savePlan(plan)
        #expect(store.scheduleWorkout(planID: plan.id, on: future))
        #expect(store.scheduledWorkouts.count == 1)
        #expect(store.scheduledWorkout(on: future)?.plan?.id == plan.id)
        store.removeScheduledWorkout(store.scheduledWorkouts[0].id)
        #expect(store.scheduledWorkouts.isEmpty)
        #expect(store.plans.count == 1)
    }

    @Test func assignedCalendarDaySurvivesTimezoneChanges() {
        let scheduled = ScheduledWorkout(day: DateComponents(year: 2027, month: 3, day: 14),
            plan: WorkoutCatalog.defaultPlan, gymID: "rpac")
        var calendar = Calendar(identifier: .gregorian)
        for zone in ["America/New_York", "Asia/Tokyo"] {
            calendar.timeZone = TimeZone(identifier: zone)!
            let date = scheduled.date(in: calendar)!
            #expect(calendar.component(.day, from: date) == 14)
            #expect(scheduled.isOn(date, calendar: calendar))
        }
    }
}
