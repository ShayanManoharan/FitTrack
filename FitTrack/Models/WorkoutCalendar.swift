import Foundation

enum WorkoutDayStatus: String, CaseIterable {
    case complete, partial, skipped, rest, planned
    var label: String {
        switch self {
        case .complete: "Completed workout"
        case .partial: "Partially completed"
        case .skipped: "Skipped workout"
        case .rest: "Rest day"
        case .planned: "Scheduled workout"
        }
    }
}

struct CalendarWorkoutRecord: Identifiable {
    let id: String
    let date: Date
    let status: WorkoutDayStatus
    let title: String
    let minutes: Int?
    let location: String?
    let completed: Int?
    let total: Int?
}

struct WorkoutCalendarState {
    enum Mode: String, CaseIterable { case month = "Month", week = "Week", year = "Year" }
    var mode: Mode = .month
    private(set) var today: Date
    private(set) var selected: Date
    private(set) var cursor: Date
    let calendar: Calendar

    init(now: Date = Date(), calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
        today = calendar.startOfDay(for: now)
        selected = today
        cursor = calendar.dateInterval(of: .month, for: now)!.start
    }

    var monthStart: Date { calendar.dateInterval(of: .month, for: cursor)!.start }
    var weekStart: Date {
        let offset = (calendar.component(.weekday, from: cursor) + 5) % 7
        return calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: cursor))!
    }
    var dates: [Date] {
        let start: Date
        if mode == .week { start = weekStart }
        else {
            let offset = (calendar.component(.weekday, from: monthStart) + 5) % 7
            start = calendar.date(byAdding: .day, value: -offset, to: monthStart)!
        }
        return (0..<(mode == .week ? 7 : 42)).map { calendar.date(byAdding: .day, value: $0, to: start)! }
    }
    var months: [Date] {
        let start = calendar.dateInterval(of: .year, for: cursor)!.start
        return (0..<12).map { calendar.date(byAdding: .month, value: $0, to: start)! }
    }
    mutating func select(_ date: Date) {
        selected = calendar.startOfDay(for: date)
        if mode == .month && !calendar.isDate(date, equalTo: cursor, toGranularity: .month) {
            cursor = calendar.dateInterval(of: .month, for: date)!.start
        }
    }
    mutating func setMode(_ mode: Mode) {
        self.mode = mode
        cursor = mode == .week ? selected : monthStart
    }
    mutating func shift(_ direction: Int) {
        switch mode {
        case .month: cursor = calendar.date(byAdding: .month, value: direction, to: monthStart)!
        case .week: cursor = calendar.date(byAdding: .day, value: direction * 7, to: cursor)!
        case .year: cursor = calendar.date(byAdding: .year, value: direction, to: monthStart)!
        }
    }
    mutating func openMonth(_ month: Date) {
        cursor = calendar.dateInterval(of: .month, for: month)!.start
        mode = .month
    }
    mutating func goToToday(now: Date = Date()) {
        today = calendar.startOfDay(for: now)
        selected = today
        cursor = mode == .week ? today : calendar.dateInterval(of: .month, for: today)!.start
    }
    mutating func refreshToday(_ now: Date) { today = calendar.startOfDay(for: now) }
}

struct WorkoutCalendarSnapshot {
    let calendar: Calendar
    let recordsByDay: [Date: [CalendarWorkoutRecord]]
    init(records: [CalendarWorkoutRecord], calendar: Calendar) {
        self.calendar = calendar
        recordsByDay = Dictionary(grouping: records) { calendar.startOfDay(for: $0.date) }
    }
    func records(on day: Date) -> [CalendarWorkoutRecord] {
        (recordsByDay[calendar.startOfDay(for: day)] ?? []).sorted { $0.date < $1.date }
    }
    func status(on day: Date) -> WorkoutDayStatus? {
        let all = records(on: day).map(\.status)
        let finished = all.filter { $0 != .planned && $0 != .rest }
        let statuses = finished.isEmpty ? all : finished
        guard !statuses.isEmpty else { return nil }
        if statuses.allSatisfy({ $0 == .complete }) { return .complete }
        if statuses.contains(.partial) || statuses.contains(.complete) { return .partial }
        if statuses.contains(.skipped) { return .skipped }
        if statuses.contains(.planned) { return .planned }
        return .rest
    }
    func count(_ status: WorkoutDayStatus, month: Date, through today: Date? = nil) -> Int {
        recordsByDay.keys.filter { day in
            calendar.isDate(day, equalTo: month, toGranularity: .month)
            && (today == nil || day <= calendar.startOfDay(for: today!))
            && self.status(on: day) == status
        }.count
    }
    func streak(through today: Date) -> Int {
        var day = calendar.startOfDay(for: today)
        if status(on: day) != .complete { day = calendar.date(byAdding: .day, value: -1, to: day)! }
        var count = 0
        // Bound traversal by known data; designated rest days do not break the streak.
        for _ in 0...recordsByDay.count {
            switch status(on: day) {
            case .complete: count += 1
            case .rest: break
            default: return count
            }
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }
}

enum WorkoutCalendarRecords {
    /// Both Home and Calendar use acknowledged cloud workouts and local calendar assignments.
    /// Draft sessions and old local history never resurrect deleted or unsaved cloud records.
    static func snapshot(workouts: [Workout], schedules: [ScheduledWorkout], gyms: [Gym],
                         calendar: Calendar = Calendar(identifier: .gregorian)) -> WorkoutCalendarSnapshot {
        let names = Dictionary(uniqueKeysWithValues: gyms.map { ($0.id, $0.name) })
        let records = saved(workouts: workouts, calendar: calendar)
            + scheduled(schedules, excluding: [], gymNames: names, calendar: calendar)
        return WorkoutCalendarSnapshot(records: records, calendar: calendar)
    }

    static func scheduled(_ schedules: [ScheduledWorkout], excluding linkedIDs: Set<UUID>,
                          gymNames: [String: String], calendar: Calendar) -> [CalendarWorkoutRecord] {
        schedules.compactMap { scheduled in
            guard !linkedIDs.contains(scheduled.id), let date = scheduled.date(in: calendar) else { return nil }
            return CalendarWorkoutRecord(id: "schedule-\(scheduled.id)", date: date, status: scheduled.isRestDay ? .rest : .planned,
                title: scheduled.plan?.name ?? "Rest Day", minutes: nil,
                location: scheduled.isRestDay ? nil : gymNames[scheduled.gymID] ?? scheduled.gymID,
                completed: nil, total: scheduled.plan?.exercises.count)
        }
    }

    static func saved(history: [WorkoutSession], pending: WorkoutSession?,
                      gymNames: [String: String], calendar: Calendar) -> [CalendarWorkoutRecord] {
        var sessions = history
        if let pending, !sessions.contains(where: { $0.id == pending.id }) { sessions.append(pending) }
        return sessions.map { session in
            let completed = session.completedCount
            let anySets = session.exercises.flatMap(\.sets).contains(where: \.isComplete)
            let status: WorkoutDayStatus = session.finishedAt == nil ? .planned
                : !session.exercises.isEmpty && completed == session.exercises.count ? .complete
                : anySets ? .partial : .skipped
            return CalendarWorkoutRecord(id: session.id.uuidString, date: session.finishedAt ?? session.startedAt,
                status: status, title: session.name,
                minutes: session.finishedAt.map { max(0, Int($0.timeIntervalSince(session.startedAt) / 60)) },
                location: gymNames[session.gymID] ?? session.gymID,
                completed: session.finishedAt == nil ? nil : completed, total: session.exercises.count)
        }
    }

    static func saved(workouts: [Workout], history: [WorkoutSession], pending: WorkoutSession?,
                      gymNames: [String: String], calendar: Calendar) -> [CalendarWorkoutRecord] {
        let remoteIDs = Set(workouts.map(\.workoutID))
        let localHistory = history.filter { !remoteIDs.contains($0.id.uuidString) }
        let localPending = pending.flatMap { remoteIDs.contains($0.id.uuidString) ? nil : $0 }
        return saved(workouts: workouts, calendar: calendar)
            + saved(history: localHistory, pending: localPending, gymNames: gymNames, calendar: calendar)
    }

    static func saved(workouts: [Workout], calendar: Calendar) -> [CalendarWorkoutRecord] {
        workouts.map { workout in
            let completed = workout.exercises.filter { exercise in
                guard !(exercise.isSkipped ?? false) else { return false }
                if let targets = exercise.setResults {
                    return !targets.isEmpty && targets.allSatisfy(\.isComplete)
                }
                // Older documents did not contain per-set results.
                return exercise.sets > 0
            }.count
            let skipped = workout.exercises.allSatisfy { $0.isSkipped ?? false }
            let hasCompletedSets = workout.exercises.contains { $0.sets > 0 }
            let status: WorkoutDayStatus = workout.exercises.isEmpty || skipped && !hasCompletedSets ? .skipped
                : completed == workout.exercises.count ? .complete
                : hasCompletedSets ? .partial : .skipped
            return CalendarWorkoutRecord(
                id: workout.workoutID,
                date: workout.date,
                status: status,
                title: workout.workoutType,
                minutes: workout.duration > 0 ? workout.duration / 60 : nil,
                location: workout.gymName ?? workout.gymID,
                completed: completed,
                total: workout.exercises.count
            )
        }
    }
}
