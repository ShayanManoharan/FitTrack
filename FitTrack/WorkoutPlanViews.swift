import SwiftUI

struct SavedPlansView: View {
    @ObservedObject var store: WorkoutStore
    let onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(store.plans.count) \(store.plans.count == 1 ? "plan" : "plans") saved")
                    .font(.subheadline).foregroundStyle(FitTrackStyle.muted)
                if store.plans.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet.clipboard").font(.largeTitle).foregroundStyle(FitTrackStyle.accent)
                        Text("No workout plans yet").font(.headline)
                        Text("Create a plan and choose the exercises for your next workout.")
                            .font(.subheadline).foregroundStyle(FitTrackStyle.muted).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(.vertical, 24).fitTrackCard()
                }
                ForEach(store.plans) { plan in
                    NavigationLink {
                        PlanDetailView(store: store, planID: plan.id, onStart: onStart)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(plan.name).font(.headline).foregroundStyle(FitTrackStyle.ink)
                                Text("\(plan.exercises.count) exercises · Tap to view")
                                    .font(.caption).foregroundStyle(FitTrackStyle.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.bold())
                        }.fitTrackCard()
                    }.buttonStyle(.plain)
                }
                NavigationLink { PlanEditorView(store: store, plan: nil) } label: {
                    Text("＋ Create workout plan")
                }.buttonStyle(FitTrackOutline())
            }.padding(22)
        }.navigationTitle("Saved workout plans").navigationBarTitleDisplayMode(.inline).fitTrackScreen()
    }
}

private struct PlanDetailView: View {
    @ObservedObject var store: WorkoutStore
    let planID: UUID
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showEditor = false
    private var plan: WorkoutPlan? { store.plans.first { $0.id == planID } }

    var body: some View {
        ScrollView {
            if let plan {
                VStack(alignment: .leading, spacing: 16) {
                    Text(plan.name).font(.title2.bold())
                    Text("\(plan.exercises.count) exercises").foregroundStyle(FitTrackStyle.muted)
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(plan.exercises.enumerated()), id: \.element.id) { index, exercise in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)").font(.subheadline.bold()).foregroundStyle(FitTrackStyle.accent)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name).font(.headline)
                                    Text("\(exercise.muscleGroup) · \(exercise.equipment)")
                                        .font(.caption).foregroundStyle(FitTrackStyle.muted)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }.fitTrackCard()
                    Button("EDIT PLAN") { showEditor = true }.buttonStyle(FitTrackPrimary())
                    Button(store.hasPendingSession ? "RESUME CURRENT WORKOUT" : "START WORKOUT →") {
                        store.startWorkout(plan: plan)
                        onStart()
                    }.buttonStyle(FitTrackOutline()).disabled(store.isSaving)
                }.padding(22)
            }
        }.navigationTitle("Workout plan").navigationBarTitleDisplayMode(.inline).fitTrackScreen()
            .sheet(isPresented: $showEditor, onDismiss: {
                if plan == nil { dismiss() }
            }) {
                if let plan {
                    NavigationStack { PlanEditorView(store: store, plan: plan) }
                        .presentationDragIndicator(.visible).presentationDetents([.large])
                }
            }
    }
}

struct PlanEditorView: View {
    @ObservedObject var store: WorkoutStore
    let plan: WorkoutPlan?
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkoutPlanDraft
    @State private var customName = ""
    @State private var confirmDelete = false
    // Keep the prototype's seven choices; preserve any other exercises already in a plan.
    private let catalog = Array(WorkoutCatalog.exercises.prefix(7))

    init(store: WorkoutStore, plan: WorkoutPlan?) {
        self.store = store
        self.plan = plan
        _draft = State(initialValue: WorkoutPlanDraft(plan: plan))
    }

    private var candidate: WorkoutPlanDraft {
        var result = draft
        result.addCustomExercise(named: customName)
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(plan == nil ? "Name the workout and choose the exercises it includes." : "Update the name and exercises in this plan.")
                    .font(.subheadline).foregroundStyle(FitTrackStyle.muted)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workout name").font(.subheadline.bold())
                    TextField("e.g., Upper Body Strength", text: $draft.name)
                        .textFieldStyle(.roundedBorder).accessibilityLabel("Workout name")
                        .accessibilityIdentifier("planName")
                }
                Text("Exercises").font(.subheadline.bold())
                VStack(spacing: 0) {
                    ForEach(catalog) { exercise in
                        let selected = draft.exercises.contains { $0.exerciseID == exercise.exerciseID }
                        Button { draft.toggle(exercise) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selected ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 20)).foregroundStyle(FitTrackStyle.accent)
                                Text(exercise.name).font(.subheadline).foregroundStyle(FitTrackStyle.ink)
                                Spacer()
                            }.frame(minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel(exercise.name)
                            .accessibilityValue(selected ? "Selected" : "Not selected")
                            .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }.fitTrackCard()

                ForEach($draft.exercises) { $exercise in
                    if !catalog.contains(where: { $0.exerciseID == exercise.exerciseID }) {
                        HStack {
                            TextField("Custom exercise name", text: $exercise.name)
                                .textFieldStyle(.roundedBorder).accessibilityLabel("Custom exercise name")
                            Button(role: .destructive) {
                                let id = exercise.id
                                draft.exercises.removeAll { $0.id == id }
                            } label: {
                                Image(systemName: "minus.circle").frame(width: 44, height: 44)
                            }.accessibilityLabel("Remove \(exercise.name)")
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Additional exercise (optional)").font(.subheadline.bold())
                    HStack {
                        TextField("Add an exercise", text: $customName).textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Additional exercise").accessibilityIdentifier("customExerciseName")
                        Button("Add") { draft.addCustomExercise(named: customName); customName = "" }
                            .font(.subheadline.bold()).frame(minWidth: 44, minHeight: 44)
                            .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                Text("\(candidate.exercises.count) exercises selected").font(.caption).foregroundStyle(FitTrackStyle.muted)
                if let message = candidate.validationMessage {
                    Text(message).font(.footnote).foregroundStyle(FitTrackStyle.muted)
                }
                Button(plan == nil ? "SAVE WORKOUT PLAN" : "SAVE CHANGES") {
                    guard let updated = candidate.makePlan() else { return }
                    store.savePlan(updated)
                    dismiss()
                }.buttonStyle(FitTrackPrimary()).disabled(candidate.validationMessage != nil)
                    .accessibilityIdentifier("saveWorkoutPlan")
                if plan != nil {
                    Button("Delete workout plan", role: .destructive) { confirmDelete = true }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.red.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Button("Cancel") { dismiss() }.frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(FitTrackStyle.muted)
            }.padding(22)
        }.navigationTitle(plan == nil ? "Create workout plan" : "Edit workout plan")
            .navigationBarTitleDisplayMode(.inline).fitTrackScreen()
            .alert("Delete \(plan?.name ?? "plan")?", isPresented: $confirmDelete) {
                Button("Delete plan", role: .destructive) {
                    if let plan { store.deletePlan(plan.id) }
                    dismiss()
                }
                Button("Keep plan", role: .cancel) { }
            } message: { Text("This saved workout plan and its exercise list will be removed. Completed workouts will remain in your history.") }
    }
}
