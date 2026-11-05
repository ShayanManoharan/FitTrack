import SwiftUI

struct WorkoutCalendarView: View {
    @ObservedObject var store: WorkoutStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var state = WorkoutCalendarState()
    @State private var showScheduler = false
    @State private var confirmRestDay = false
    @State private var confirmRemoveSchedule = false
    @Environment(\.dynamicTypeSize) private var dynamicType
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var snapshot: WorkoutCalendarSnapshot {
        var records = WorkoutCalendarRecords.saved(history: store.history, pending: store.hasPendingSession ? store.session : nil,
                gymNames: Dictionary(uniqueKeysWithValues: WorkoutStore.gyms.map { ($0.id, $0.name) }),
                calendar: state.calendar)
        let linked = Set((store.history + (store.session.map { [$0] } ?? [])).compactMap(\.scheduledWorkoutID))
        records += WorkoutCalendarRecords.scheduled(store.scheduledWorkouts, excluding: linked,
            gymNames: Dictionary(uniqueKeysWithValues: WorkoutStore.gyms.map { ($0.id, $0.name) }), calendar: state.calendar)
        return WorkoutCalendarSnapshot(records: records, calendar: state.calendar)
    }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width > 700
            let compact = geometry.size.height < 720
            let data = snapshot
            ScrollView {
                VStack(alignment: .leading, spacing: compact ? 6 : 9) {
                    header
                    if wide {
                        HStack(alignment: .top, spacing: 22) {
                            VStack(spacing: 9) { modeSwitch; calendarCard(data, compact: true); legend }
                                .frame(maxWidth: .infinity)
                            VStack(spacing: 9) { details(data); statistics(data) }.frame(maxWidth: .infinity)
                        }
                    } else {
                        modeSwitch
                        calendarCard(data, compact: compact)
                        legend
                        details(data)
                        statistics(data)
                    }
                }.padding(.horizontal, wide ? 26 : 20).padding(.top, compact ? 7 : 12).padding(.bottom, 10)
                    .frame(maxWidth: 1100).frame(maxWidth: .infinity)
            }
            // Compact reference layout at normal text sizes, with scrolling as a
            // fallback on small screens, large text, or days with multiple workouts.
            .fitTrackScreen()
        }
        .sheet(isPresented: $showScheduler) {
            NavigationStack {
                ScheduleWorkoutView(store: store, date: state.selected, calendar: state.calendar)
            }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .alert("Remove calendar assignment?", isPresented: $confirmRemoveSchedule) {
            Button("Remove", role: .destructive) {
                if let scheduled = store.scheduledWorkout(on: state.selected, calendar: state.calendar) {
                    store.removeScheduledWorkout(scheduled.id)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This removes the calendar assignment, not the saved plan or completed workout history.") }
        .alert("Make this a rest day?", isPresented: $confirmRestDay) {
            Button("Make rest day") { store.scheduleRestDay(on: state.selected, calendar: state.calendar) }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This replaces the workout assigned to this date. Your saved plan and completed history will stay unchanged.") }
        .onChange(of: scenePhase) { _, phase in if phase == .active { state.refreshToday(Date()) } }
        .onAppear { state.refreshToday(Date()); print("[Lifecycle] CalendarView appeared") }
        .onDisappear { print("[Lifecycle] CalendarView disappeared") }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Calendar").font(.system(size: 25, weight: .bold)).tracking(-0.8).accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 8)
            Button("Today") { state.goToToday() }
                .font(.system(size: 12, weight: .bold)).foregroundStyle(FitTrackStyle.accent)
                .padding(.horizontal, 12).frame(minHeight: 36)
                .background(FitTrackStyle.pale).clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel("Go to today")
                .accessibilityIdentifier("calendarToday")
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 4) {
            ForEach(WorkoutCalendarState.Mode.allCases, id: \.self) { mode in
                Button { state.setMode(mode) } label: {
                    Text(mode.rawValue).font(.system(size: 12, weight: .bold))
                        .foregroundStyle(state.mode == mode ? FitTrackStyle.accent : FitTrackStyle.muted)
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(state.mode == mode ? FitTrackStyle.surface : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain).accessibilityAddTraits(state.mode == mode ? .isSelected : [])
                    .accessibilityIdentifier("calendarMode\(mode.rawValue)")
            }
        }.padding(3).background(FitTrackStyle.detail).clipShape(RoundedRectangle(cornerRadius: 13))
    }

    private func calendarCard(_ data: WorkoutCalendarSnapshot, compact: Bool) -> some View {
        VStack(spacing: compact ? 5 : 9) {
            HStack {
                Text(periodTitle).font(.system(size: 15, weight: .bold)).lineLimit(2)
                    .accessibilityIdentifier("calendarPeriod")
                Spacer(minLength: 4)
                arrow("chevron.left", label: "Previous period", direction: -1)
                arrow("chevron.right", label: "Next period", direction: 1)
            }
            if state.mode == .year {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
                    ForEach(state.months, id: \.self) { month in
                        Button { state.openMonth(month) } label: {
                            VStack(spacing: 4) {
                                Text(format(month, "MMM")).font(.system(size: 11, weight: .bold))
                                HStack(spacing: 3) {
                                    ForEach([WorkoutDayStatus.complete, .partial, .skipped, .rest, .planned], id: \.self) { status in
                                        Circle().fill(data.count(status, month: month) > 0 ? status.fill : .clear).frame(width: 5, height: 5)
                                    }
                                }
                            }.frame(maxWidth: .infinity, minHeight: 32).padding(3)
                                .background(FitTrackStyle.background).clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(FitTrackStyle.line.opacity(0.5)))
                        }.buttonStyle(.plain).accessibilityLabel(format(month, "MMMM yyyy"))
                    }
                }
                Text("Tap a month to open its calendar.").font(.system(size: 10)).foregroundStyle(FitTrackStyle.muted)
            } else {
                LazyVGrid(columns: columns, spacing: compact ? 1 : 3) {
                    ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, day in
                        Text(day).font(.system(size: 11, weight: .bold)).foregroundStyle(FitTrackStyle.tabMuted)
                            .frame(maxWidth: .infinity).padding(.bottom, 4).accessibilityHidden(true)
                    }
                    ForEach(state.dates, id: \.self) { date in dayButton(date, data: data, compact: compact) }
                }
            }
        }.padding(12).calendarCard()
    }

    private func arrow(_ symbol: String, label: String, direction: Int) -> some View {
        Button { state.shift(direction) } label: {
            Image(systemName: symbol).font(.system(size: 12, weight: .bold))
                .frame(width: 28, height: 28).background(FitTrackStyle.surface)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(FitTrackStyle.line.opacity(0.5)))
        }.accessibilityLabel(label)
    }

    private func dayButton(_ date: Date, data: WorkoutCalendarSnapshot, compact: Bool) -> some View {
        let status = data.status(on: date)
        let today = state.calendar.isDate(date, inSameDayAs: state.today)
        let selected = state.calendar.isDate(date, inSameDayAs: state.selected)
        let other = state.mode == .month && !state.calendar.isDate(date, equalTo: state.cursor, toGranularity: .month)
        let size: CGFloat = dynamicType.isAccessibilitySize ? 40 : compact ? 26 : 30
        return Button { state.select(date) } label: {
            Text("\(state.calendar.component(.day, from: date))")
                .font(.system(size: 12, weight: today ? .heavy : .regular))
                .foregroundStyle(status?.ink ?? (other ? FitTrackStyle.line : FitTrackStyle.ink))
                .frame(width: size, height: size).background(status?.fill ?? .clear).clipShape(Circle())
                .overlay(Circle().stroke(today ? FitTrackStyle.accent : .clear, lineWidth: 2))
                .overlay(Circle().stroke(selected ? FitTrackStyle.ink : .clear, lineWidth: 2).padding(-3))
                .frame(maxWidth: .infinity)
        }.buttonStyle(.plain)
            .accessibilityLabel("\(format(date, "EEEE, MMMM d, yyyy")), \(status?.label ?? "No workout")\(today ? ", Today" : "")")
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { legendItems }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), alignment: .leading, spacing: 5) { legendItems }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    @ViewBuilder private var legendItems: some View {
        ForEach([WorkoutDayStatus.complete, .partial, .skipped, .rest, .planned], id: \.self) { status in
            HStack(spacing: 4) {
                Circle().fill(status.fill).frame(width: 8, height: 8)
                Text(status == .complete ? "Completed" : status == .planned ? "Scheduled" : status.rawValue.capitalized)
            }.font(.system(size: 9)).foregroundStyle(FitTrackStyle.muted)
        }
        HStack(spacing: 4) {
            Circle().stroke(FitTrackStyle.accent, lineWidth: 2).frame(width: 9, height: 9)
            Text("Today")
        }.font(.system(size: 9)).foregroundStyle(FitTrackStyle.muted)
    }

    private func details(_ data: WorkoutCalendarSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Selected day", subtitle: "Tap a date to view")
            let records = data.records(on: state.selected)
            if records.isEmpty {
                detailCard(nil)
            } else {
                ForEach(records) { record in detailCard(record) }
            }
            let assignment = store.scheduledWorkout(on: state.selected, calendar: state.calendar)
            if state.selected >= state.today {
                Button(assignment == nil || assignment?.isRestDay == true ? "＋ Schedule workout" : "Change scheduled workout") {
                    showScheduler = true
                }.buttonStyle(FitTrackOutline())
                    .disabled(assignment?.isRestDay == true)
                    .opacity(assignment?.isRestDay == true ? 0.4 : 1)
                    .accessibilityHint(assignment?.isRestDay == true ? "Remove the rest day before scheduling a workout" : "Choose a workout plan for this date")
                    .accessibilityIdentifier("scheduleWorkout")
                if assignment?.isRestDay == true {
                    Text("Remove the rest day to schedule a workout.")
                        .font(.footnote).foregroundStyle(FitTrackStyle.muted)
                }
            }
            if state.selected >= state.today && assignment?.isRestDay != true {
                Button("Make rest day") {
                    if assignment != nil { confirmRestDay = true }
                    else { store.scheduleRestDay(on: state.selected, calendar: state.calendar) }
                }.buttonStyle(FitTrackOutline()).accessibilityIdentifier("makeRestDay")
            }
            if assignment != nil {
                Button(assignment?.isRestDay == true ? "Remove rest day" : "Remove scheduled workout", role: .destructive) { confirmRemoveSchedule = true }
                    .font(.system(size: 12)).frame(minHeight: 36)
            }
        }
    }

    private func detailCard(_ record: CalendarWorkoutRecord?) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(format(state.selected, "EEEE, MMMM d, yyyy").uppercased())
                .font(.system(size: 10, weight: .heavy)).tracking(0.7).foregroundStyle(FitTrackStyle.accent)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { detailTitle(record); detailBadge(record) }
                VStack(alignment: .leading, spacing: 5) { detailTitle(record); detailBadge(record) }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                detailStat("Time", value: record?.minutes.map { "\($0) min" } ?? "—")
                detailStat("Location", value: record?.location ?? "—")
                detailStat("Exercises completed", value: record.flatMap { r in r.completed.map { "\($0) / \(r.total ?? 0)" } } ?? "—")
            }
        }.padding(12).calendarCard()
    }
    private func detailTitle(_ record: CalendarWorkoutRecord?) -> some View {
        Text(record?.title ?? (state.selected < state.today ? "No workout recorded" : "No workout scheduled"))
            .font(.system(size: 16, weight: .bold)).fixedSize(horizontal: false, vertical: true)
    }
    private func detailBadge(_ record: CalendarWorkoutRecord?) -> some View {
        let today = state.calendar.isDate(state.selected, inSameDayAs: state.today)
        return Text((record?.status.label ?? "No workout") + (today ? " · Today" : ""))
            .font(.system(size: 10, weight: .semibold)).foregroundStyle(record?.status.ink ?? FitTrackStyle.muted)
            .padding(.horizontal, 7).padding(.vertical, 5).background(record?.status.fill ?? FitTrackStyle.detail)
            .clipShape(Capsule()).fixedSize(horizontal: true, vertical: false)
    }
    private func detailStat(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 9)).foregroundStyle(FitTrackStyle.muted)
            Text(value).font(.system(size: 12, weight: .bold)).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 7).padding(.horizontal, 9)
            .background(FitTrackStyle.detail).clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func statistics(_ data: WorkoutCalendarSnapshot) -> some View {
        VStack(spacing: 6) {
            sectionTitle("This month", subtitle: format(state.monthStart, "MMMM yyyy"))
            HStack(spacing: 6) {
                statistic("Completed", number: data.count(.complete, month: state.monthStart, through: state.today), color: WorkoutDayStatus.complete.fill, ink: FitTrackStyle.accent)
                statistic("Partial", number: data.count(.partial, month: state.monthStart, through: state.today), color: WorkoutDayStatus.partial.fill, ink: WorkoutDayStatus.partial.ink)
                statistic("Workout streak", number: data.streak(through: state.today), color: FitTrackStyle.pale, ink: FitTrackStyle.accent, flame: true)
            }
        }
    }
    private func statistic(_ title: String, number: Int, color: Color, ink: Color, flame: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(number)\(flame ? " 🔥" : "")").font(.system(size: 17, weight: .bold)).foregroundStyle(ink)
            Text(title).font(.system(size: 9)).foregroundStyle(FitTrackStyle.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 7).padding(.horizontal, 8)
            .background(color).clipShape(RoundedRectangle(cornerRadius: 12))
    }
    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        HStack {
            Text(title).font(.system(size: 14, weight: .bold))
            Spacer(minLength: 4)
            Text(subtitle).font(.system(size: 10)).foregroundStyle(FitTrackStyle.muted)
        }
    }
    private var periodTitle: String {
        switch state.mode {
        case .month: format(state.cursor, "MMMM yyyy")
        case .year: format(state.cursor, "yyyy")
        case .week: "\(format(state.weekStart, "MMM d")) – \(format(state.calendar.date(byAdding: .day, value: 6, to: state.weekStart)!, "MMM d, yyyy"))"
        }
    }
    private func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.calendar = state.calendar
        formatter.timeZone = state.calendar.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

private extension View {
    func calendarCard() -> some View {
        background(FitTrackStyle.surface).clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: FitTrackStyle.ink.opacity(0.04), radius: 7, y: 3)
    }
}
private extension WorkoutDayStatus {
    var fill: Color {
        switch self {
        case .complete: Color(red: 212/255, green: 240/255, blue: 227/255)
        case .partial: Color(red: 1, green: 237/255, blue: 189/255)
        case .skipped: Color(red: 249/255, green: 216/255, blue: 214/255)
        case .rest: Color(red: 229/255, green: 236/255, blue: 242/255)
        case .planned: FitTrackStyle.pale
        }
    }
    var ink: Color {
        switch self {
        case .complete: Color(red: 18/255, green: 103/255, blue: 70/255)
        case .partial: Color(red: 134/255, green: 89/255, blue: 0)
        case .skipped: Color(red: 165/255, green: 61/255, blue: 55/255)
        case .rest: Color(red: 96/255, green: 117/255, blue: 133/255)
        case .planned: FitTrackStyle.accent
        }
    }
}
