import SwiftUI

struct ScheduleWorkoutView: View {
    @ObservedObject var store: WorkoutStore
    let date: Date
    let calendar: Calendar
    @State private var selectedPlanID: UUID?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    init(store: WorkoutStore, date: Date, calendar: Calendar) {
        self.store = store
        self.date = date
        self.calendar = calendar
        _selectedPlanID = State(initialValue: store.scheduledWorkout(on: date, calendar: calendar)?.plan?.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(.headline).foregroundStyle(FitTrackStyle.accent)
                Text("Choose a saved workout plan for this date. You can change or remove the assignment later.")
                    .font(.subheadline).foregroundStyle(FitTrackStyle.muted)
                if store.plans.isEmpty {
                    Text("No saved plans yet. Create a workout plan first, then assign it to this date.")
                        .font(.subheadline).fitTrackCard()
                }
                ForEach(store.plans) { plan in
                    Button { selectedPlanID = plan.id; errorMessage = nil } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(plan.name).font(.headline).foregroundStyle(FitTrackStyle.ink)
                                Text("\(plan.exercises.count) exercises").font(.caption).foregroundStyle(FitTrackStyle.muted)
                            }
                            Spacer()
                            Image(systemName: selectedPlanID == plan.id ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(FitTrackStyle.accent)
                        }.fitTrackCard()
                    }.buttonStyle(.plain).accessibilityAddTraits(selectedPlanID == plan.id ? .isSelected : [])
                }
                NavigationLink { PlanEditorView(store: store, plan: nil) } label: {
                    Text("＋ Create workout plan")
                }.buttonStyle(FitTrackOutline())
                Text("Location: \(store.gymName)").font(.footnote).foregroundStyle(FitTrackStyle.muted)
                if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
                Button("SCHEDULE WORKOUT") {
                    guard let id = selectedPlanID else { return }
                    if store.scheduleWorkout(planID: id, on: date, calendar: calendar) { dismiss() }
                    else { errorMessage = "Choose an existing plan and a date that is today or later." }
                }.buttonStyle(FitTrackPrimary())
                    .disabled(!store.plans.contains { $0.id == selectedPlanID })
                    .accessibilityIdentifier("confirmScheduleWorkout")
            }.padding(22)
        }.navigationTitle("Schedule workout").navigationBarTitleDisplayMode(.inline).fitTrackScreen()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onChange(of: store.plans) { old, updated in
                if updated.count > old.count { selectedPlanID = updated.last?.id }
                else if !updated.contains(where: { $0.id == selectedPlanID }) { selectedPlanID = nil }
            }
    }
}
