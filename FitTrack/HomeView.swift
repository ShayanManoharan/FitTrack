import SwiftUI

struct HomeView: View {
    @ObservedObject var store: WorkoutStore
    let onStartWorkout: () -> Void
    @State private var sheet: HomeSheet?
    @AppStorage("fittrack.native.displayName") private var displayName = "Kevin"

    private enum HomeSheet: String, Identifiable {
        case gyms, plans, create
        var id: String { rawValue }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if geometry.size.width > 700 {
                        HStack(alignment: .top, spacing: 24) {
                            VStack(spacing: 18) { gym; planActions }.frame(maxWidth: .infinity)
                            todayWorkout.frame(maxWidth: .infinity)
                        }
                    } else { gym; todayWorkout; planActions }
                    if let message = store.storageMessage {
                        Text(message).font(.footnote).foregroundStyle(.red)
                    }
                }.padding(.horizontal, 21).padding(.top, 16).padding(.bottom, 12)
                    .frame(maxWidth: 1100).frame(maxWidth: .infinity)
            }.fitTrackScreen()
        }
        .sheet(item: $sheet) { route in
            NavigationStack {
                Group {
                    switch route {
                    case .gyms: gymChoices
                    case .plans: SavedPlansView(store: store, onStart: onStartWorkout)
                    case .create: PlanEditorView(store: store, plan: nil)
                    }
                }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { sheet = nil } } }
            }.tint(FitTrackStyle.accent).preferredColorScheme(.light)
                .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FITTRACK").font(.system(size: 12, weight: .heavy)).tracking(1.4)
                .foregroundStyle(FitTrackStyle.accent).padding(.bottom, 9)
            HStack {
                Text("Hi, \(displayName)").font(.system(size: 26, weight: .bold)).tracking(-0.7)
                Spacer()
                Text("🔥 \(store.streak)-day streak").font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color(red: 0.53, green: 0.32, blue: 0.09))
                    .padding(.horizontal, 11).padding(.vertical, 8)
                    .background(Color(red: 1, green: 0.94, blue: 0.86)).clipShape(Capsule())
            }
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(size: 12)).foregroundStyle(FitTrackStyle.muted)
        }
    }

    private var gym: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current gym").font(.system(size: 16, weight: .bold))
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow(text: "Your location")
                    Text(store.gymName).font(.system(size: 18, weight: .bold))
                    Text("Columbus, OH").font(.system(size: 12)).foregroundStyle(FitTrackStyle.muted)
                }
                Spacer()
                Button("Find gyms →") { sheet = .gyms }
                    .font(.system(size: 12, weight: .bold)).padding(10)
                    .background(FitTrackStyle.pale).clipShape(RoundedRectangle(cornerRadius: 10))
            }.fitTrackCard()
        }
    }

    private var todayWorkout: some View {
        let session = store.session
        let title = store.hasPendingSession ? session?.name ?? store.todayPlan.name : store.todayPlan.name
        let total = store.hasPendingSession ? session?.exercises.count ?? 0 : store.todayPlan.exercises.count
        let done = store.hasPendingSession ? session?.completedCount ?? 0 : 0
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's workout").font(.system(size: 16, weight: .bold))
                Spacer()
                Text(Date.now.formatted(.dateTime.month(.abbreviated).day())).font(.system(size: 12))
                    .foregroundStyle(FitTrackStyle.muted)
            }
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    Text(title).font(.system(size: 19, weight: .bold))
                    Spacer()
                    StatusPill(text: store.hasActiveSession ? "In progress" : store.hasPendingSession ? "Ready to save" : "Scheduled")
                }
                HStack(spacing: 8) {
                    detail("Time", value: "—")
                    detail("Location", value: store.gymName)
                }
                detail("Exercises", value: "\(done) of \(total) completed · \(total) planned")
                Button(store.hasActiveSession ? "RESUME WORKOUT →" : store.hasPendingSession ? "SAVE FINISHED WORKOUT →" : "START WORKOUT →") {
                    store.startWorkout()
                    onStartWorkout()
                }.buttonStyle(FitTrackPrimary()).disabled(store.isSaving)
            }.fitTrackCard()
        }
    }

    private func detail(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 10)).foregroundStyle(FitTrackStyle.muted)
            Text(value).font(.system(size: 13, weight: .semibold))
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
            .background(FitTrackStyle.detail).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var planActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Workout plans").font(.system(size: 16, weight: .bold))
                Spacer()
                Button("View all →") { sheet = .plans }.font(.system(size: 12, weight: .bold))
            }
            Button("＋ Create workout plan") { sheet = .create }.buttonStyle(FitTrackOutline())
            Text(store.plans.last.map { "\($0.name) · \($0.exercises.count) exercises · \(store.plans.count) plans saved" }
                 ?? "No plans saved yet.")
                .font(.system(size: 12)).foregroundStyle(FitTrackStyle.muted)
        }
    }

    private var gymChoices: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Choose a gym to use for your workouts. These are sample locations; nearby search is not connected.")
                    .font(.subheadline).foregroundStyle(FitTrackStyle.muted)
                ForEach(WorkoutStore.gyms, id: \.id) { gym in
                    Button { store.selectGym(gym.id); sheet = nil } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(gym.name).font(.headline)
                                Text("Columbus, OH").font(.caption).foregroundStyle(FitTrackStyle.muted)
                            }
                            Spacer()
                            if store.gymID == gym.id { Image(systemName: "checkmark") }
                        }.fitTrackCard()
                    }
                }
            }.padding(22)
        }.navigationTitle("Find gyms").navigationBarTitleDisplayMode(.inline).fitTrackScreen()
    }
}

struct SavedPlansView: View {
    @ObservedObject var store: WorkoutStore
    let onStart: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(store.plans.count) plans saved").foregroundStyle(FitTrackStyle.muted)
                if store.plans.isEmpty { Text("Create a workout plan to see it here.") }
                ForEach(store.plans) { plan in
                    NavigationLink {
                        PlanDetailView(store: store, planID: plan.id, onStart: onStart)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.name).font(.headline)
                            Text("\(plan.exercises.count) exercises · Tap to view").font(.caption)
                        }.frame(maxWidth: .infinity, alignment: .leading).fitTrackCard()
                    }
                }
            }.padding(22)
        }.navigationTitle("Saved workout plans").navigationBarTitleDisplayMode(.inline).fitTrackScreen()
    }
}

private struct PlanDetailView: View {
    @ObservedObject var store: WorkoutStore
    let planID: UUID
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            if let plan = store.plans.first(where: { $0.id == planID }) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(plan.name).font(.title2.bold())
                    Text("\(plan.exercises.count) exercises").foregroundStyle(FitTrackStyle.muted)
                    ForEach(Array(plan.exercises.enumerated()), id: \.element.id) { index, exercise in
                        Text("\(index + 1). \(exercise.name)")
                    }
                    NavigationLink { PlanEditorView(store: store, plan: plan) } label: { Text("EDIT PLAN") }
                        .buttonStyle(FitTrackPrimary())
                    Button(store.hasPendingSession ? "RESUME CURRENT WORKOUT" : "START WORKOUT →") {
                        store.startWorkout(plan: plan)
                        onStart()
                    }.buttonStyle(FitTrackOutline()).disabled(store.isSaving)
                }.padding(22)
            }
        }.navigationTitle("Workout plan").navigationBarTitleDisplayMode(.inline).fitTrackScreen()
            .onChange(of: store.plans) { _, plans in
                if !plans.contains(where: { $0.id == planID }) { dismiss() }
            }
    }
}

struct PlanEditorView: View {
    @ObservedObject var store: WorkoutStore
    let plan: WorkoutPlan?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selected: Set<String>
    @State private var customName: String
    @State private var confirmDelete = false
    private var catalog: [SessionExercise] { Array(WorkoutCatalog.exercises.prefix(7)) }
    private var hasExercises: Bool {
        catalog.contains { selected.contains($0.exerciseID) } || !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(store: WorkoutStore, plan: WorkoutPlan?) {
        self.store = store
        self.plan = plan
        _name = State(initialValue: plan?.name ?? "")
        _selected = State(initialValue: Set(plan?.exercises.map(\.exerciseID) ?? []))
        _customName = State(initialValue: plan?.exercises.first(where: { $0.exerciseID.hasPrefix("custom-") })?.name ?? "")
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Name the workout and choose the exercises it includes.")
                    .font(.subheadline).foregroundStyle(FitTrackStyle.muted)
                Text("Workout name").font(.subheadline.bold())
                TextField("e.g., Upper Body Strength", text: $name).textFieldStyle(.roundedBorder)
                Text("Exercises").font(.subheadline.bold())
                ForEach(catalog) { exercise in
                    Toggle(exercise.name, isOn: Binding(get: { selected.contains(exercise.exerciseID) }, set: { value in
                        if value { selected.insert(exercise.exerciseID) } else { selected.remove(exercise.exerciseID) }
                    })).toggleStyle(.switch)
                }
                Text("Additional exercise (optional)").font(.subheadline.bold())
                TextField("Add an exercise", text: $customName).textFieldStyle(.roundedBorder)
                Button(plan == nil ? "SAVE WORKOUT PLAN" : "SAVE CHANGES") {
                    var exercises = catalog.filter { selected.contains($0.exerciseID) }
                    let custom = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !custom.isEmpty {
                        exercises.append(WorkoutCatalog.exercise("custom-\(UUID().uuidString)", custom, "Custom", "Unspecified", 0, 10, 60))
                    }
                    store.savePlan(WorkoutPlan(id: plan?.id ?? UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines), exercises: exercises))
                    dismiss()
                }.buttonStyle(FitTrackPrimary())
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasExercises)
                    .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                if plan != nil {
                    Button("Delete workout plan", role: .destructive) { confirmDelete = true }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                Button("Cancel") { dismiss() }.frame(maxWidth: .infinity, minHeight: 44)
            }.padding(22)
        }.navigationTitle(plan == nil ? "Create workout plan" : "Edit workout plan")
            .navigationBarTitleDisplayMode(.inline).fitTrackScreen()
            .alert("Delete \(plan?.name ?? "plan")?", isPresented: $confirmDelete) {
                Button("Delete plan", role: .destructive) { if let plan { store.deletePlan(plan.id) }; dismiss() }
                Button("Keep plan", role: .cancel) { }
            } message: { Text("This saved workout plan and its exercise list will be removed.") }
    }
}
