import Foundation

struct WorkoutReminderPlan: Equatable {
    let scheduleID: UUID
    let title: String
    let fireDate: Date

    static func make(schedules: [ScheduledWorkout], hour: Int, minute: Int,
                     now: Date = Date(), calendar: Calendar = Calendar(identifier: .gregorian)) -> [WorkoutReminderPlan] {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return [] }
        return schedules.compactMap { assignment -> WorkoutReminderPlan? in
            guard let plan = assignment.plan, let day = assignment.date(in: calendar),
                  let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day), fire > now else { return nil }
            return WorkoutReminderPlan(scheduleID: assignment.id, title: plan.name, fireDate: fire)
        }.sorted { $0.fireDate < $1.fireDate }
    }
}
