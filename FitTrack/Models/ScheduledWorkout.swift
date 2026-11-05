import Foundation

struct ScheduledWorkout: Identifiable, Codable, Equatable {
    var id = UUID()
    // Store a calendar day, not a midnight instant that shifts when travelling.
    var day: DateComponents
    // A nil plan explicitly represents a rest-day assignment.
    var plan: WorkoutPlan?
    var gymID: String

    var isRestDay: Bool { plan == nil }

    func date(in calendar: Calendar) -> Date? { calendar.date(from: day) }
    func isOn(_ date: Date, calendar: Calendar) -> Bool {
        day == calendar.dateComponents([.year, .month, .day], from: date)
    }
}
