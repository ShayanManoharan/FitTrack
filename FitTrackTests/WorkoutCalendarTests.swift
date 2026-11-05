import Foundation
import Testing
@testable import FitTrack

@MainActor
struct WorkoutCalendarTests {
    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: "America/New_York")!
        return result
    }
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
    @Test func todayButtonReturnsToCurrentPeriodAndSelectsToday() {
        let now = date(2026, 11, 5)
        for mode in WorkoutCalendarState.Mode.allCases {
            var state = WorkoutCalendarState(now: date(2024, 2, 1), calendar: calendar)
            state.setMode(mode)
            state.shift(-3)
            state.goToToday(now: now)
            #expect(state.mode == mode)
            #expect(state.selected == now)
            #expect(state.today == now)
            if mode == .year {
                #expect(calendar.component(.year, from: state.cursor) == 2026)
            } else {
                #expect(state.dates.contains(now))
            }
        }
    }

    @Test func monthUsesSixMondayFirstWeeksAcrossDST() {
        let state = WorkoutCalendarState(now: date(2026, 11, 5), calendar: calendar)
        #expect(state.dates.count == 42)
        #expect(Set(state.dates).count == 42)
        #expect(calendar.component(.weekday, from: state.dates[0]) == 2)
        #expect(state.dates.contains(date(2026, 11, 1)))
        #expect(state.dates.contains(date(2026, 11, 30)))
    }
    @Test func selectionAndModeNavigation() {
        var state = WorkoutCalendarState(now: date(2026, 11, 5), calendar: calendar)
        state.select(date(2026, 10, 31))
        #expect(calendar.component(.month, from: state.cursor) == 10)
        state.setMode(.week)
        #expect(state.dates.count == 7)
        #expect(state.dates.contains(date(2026, 10, 31)))
        state.shift(1)
        #expect(state.dates.contains(date(2026, 11, 7)))
        state.setMode(.year)
        state.shift(1)
        #expect(calendar.component(.year, from: state.cursor) == 2027)
        #expect(state.months.count == 12)
        state.openMonth(date(2024, 2, 1))
        #expect(state.mode == .month)
        #expect(state.dates.contains(date(2024, 2, 29)))
    }
    @Test func countsMatchDayStatusesAndRestDoesNotBreakStreak() {
        func record(_ day: Int, _ status: WorkoutDayStatus, _ id: String) -> CalendarWorkoutRecord {
            CalendarWorkoutRecord(id: id, date: date(2026, 11, day), status: status, title: "Test", minutes: nil, location: nil, completed: nil, total: nil)
        }
        let data = WorkoutCalendarSnapshot(records: [record(5, .complete, "a"), record(4, .rest, "b"),
            record(3, .complete, "c"), record(2, .partial, "d"), record(1, .complete, "e"),
            record(1, .skipped, "f"), record(10, .complete, "future")], calendar: calendar)
        #expect(data.status(on: date(2026, 11, 1)) == .partial)
        #expect(data.count(.complete, month: date(2026, 11, 1), through: date(2026, 11, 5)) == 2)
        #expect(data.count(.partial, month: date(2026, 11, 1), through: date(2026, 11, 5)) == 2)
        #expect(data.streak(through: date(2026, 11, 5)) == 2)
    }
    @Test func emptyHistoryDoesNotInventPastOrFutureWorkouts() {
        let real = WorkoutCalendarRecords.saved(history: [], pending: nil,
            gymNames: ["rpac": "RPAC"], calendar: calendar)
        #expect(real.isEmpty)

    }
    @Test func savedSessionsShowPerDayResults() {
        var exercise = WorkoutCatalog.exercises[0]
        exercise.sets[0].isComplete = true
        let start = date(2026, 11, 2)
        let session = WorkoutSession(name: "Partial", startedAt: start, finishedAt: start.addingTimeInterval(1800),
            gymID: "rpac", exercises: [exercise])
        let records = WorkoutCalendarRecords.saved(history: [session], pending: nil,
            gymNames: ["rpac": "RPAC"], calendar: calendar)
        #expect(records[0].status == .partial)
        #expect(records[0].minutes == 30)
        #expect(records[0].location == "RPAC")
        #expect(records[0].completed == 0)
        #expect(records[0].total == 1)
    }
}
