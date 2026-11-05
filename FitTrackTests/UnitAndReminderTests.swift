import Foundation
import Testing
@testable import FitTrack

@MainActor
struct UnitAndReminderTests {
    @Test func unitConversionPreservesPhysicalWeight() {
        let kg = WeightUnit.kilograms
        #expect(abs(kg.fromPounds(100) - 45.359237) < 0.000001)
        #expect(abs(kg.toPounds(kg.fromPounds(95)) - 95) < 0.000001)
        #expect(kg.editingValue(fromPounds: 95) == 43.09)
        #expect(WeightUnit.pounds.fromPounds(95) == 95)
        #expect(WeightUnit(preference: "unknown") == .pounds)
    }

    @Test func remindersSkipRestDaysAndElapsedTimes() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 10))!
        let plan = WorkoutCatalog.defaultPlan
        let past = ScheduledWorkout(day: DateComponents(year: 2026, month: 11, day: 5), plan: plan, gymID: "rpac")
        let future = ScheduledWorkout(day: DateComponents(year: 2026, month: 11, day: 6), plan: plan, gymID: "rpac")
        let rest = ScheduledWorkout(day: DateComponents(year: 2026, month: 11, day: 7), plan: nil, gymID: "rpac")
        let specs = WorkoutReminderPlan.make(schedules: [past, rest, future], hour: 9, minute: 30, now: now, calendar: calendar)
        #expect(specs.count == 1)
        #expect(specs.first?.scheduleID == future.id)
        #expect(calendar.component(.hour, from: specs[0].fireDate) == 9)
        #expect(calendar.component(.minute, from: specs[0].fireDate) == 30)
        #expect(WorkoutReminderPlan.make(schedules: [future], hour: 25, minute: 0, now: now, calendar: calendar).isEmpty)
    }

    @Test func olderProfileWithoutReminderTimeStillLoads() throws {
        let settings = ProfileSettings(name: "Name", email: "name@example.com")
        var data = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        data.removeValue(forKey: "reminderHour")
        data.removeValue(forKey: "reminderMinute")
        let restored = try JSONDecoder().decode(ProfileSettings.self, from: JSONSerialization.data(withJSONObject: data))
        #expect((restored.reminderHour ?? 9) == 9)
        #expect((restored.reminderMinute ?? 0) == 0)
    }
}
