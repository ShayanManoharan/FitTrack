import SwiftUI

struct SavedWorkoutsView: View {
    @StateObject private var store = SavedWorkoutsStore()
    @State private var editing: Workout?
    @State private var deleting: Workout?

    var body: some View {
        List {
            Section {
                Text("Workouts saved to your account. Refresh to check saved changes.")
                    .font(.footnote).foregroundStyle(FitTrackStyle.muted)
                if store.isBusy { ProgressView("Loading or saving…") }
                if let error = store.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                } else if store.workouts.isEmpty && !store.isBusy {
                    Text("No saved workouts. Finish a workout and tap Save Workout first.")
                }
            }
            ForEach(store.workouts) { workout in
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(workout.workoutType).font(.headline)
                        Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                        Text("\(workout.gymName ?? workout.gymID ?? "No gym") · \(workout.exercises.count) exercises")
                        ForEach(Array(workout.exercises.enumerated()), id: \.offset) { _, exercise in
                            Text("\(exercise.name ?? exercise.exerciseID) · \(exercise.sets) sets logged")
                                .font(.caption).foregroundStyle(FitTrackStyle.muted)
                        }
                    }
                    Button("Rename workout") { editing = workout }.disabled(store.isBusy)
                    Button("Delete workout", role: .destructive) { deleting = workout }.disabled(store.isBusy)
                }
            }
        }
        .navigationTitle("Saved workouts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", action: store.load).disabled(store.isBusy)
            }
        }
        .onAppear { store.load() }
        .sheet(item: $editing) { workout in
            NavigationStack { RenameSavedWorkoutView(store: store, workout: workout) }
        }
        .alert("Delete saved workout?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), presenting: deleting) { workout in
            Button("Delete", role: .destructive) { store.delete(workout); deleting = nil }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: { _ in
            Text("This removes the workout from your account. Your workout plans and on-device progress are kept.")
        }
    }
}

private struct RenameSavedWorkoutView: View {
    @ObservedObject var store: SavedWorkoutsStore
    let workout: Workout
    @State private var name: String
    @Environment(\.dismiss) private var dismiss

    init(store: SavedWorkoutsStore, workout: Workout) {
        self.store = store
        self.workout = workout
        _name = State(initialValue: workout.workoutType)
    }

    var body: some View {
        Form {
            TextField("Workout name", text: $name)
            if let error = store.errorMessage { Text(error).foregroundStyle(.red) }
            Button("Save changes") { store.rename(workout, to: name) { dismiss() } }
                .disabled(store.isBusy || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 50)
            if store.isBusy { ProgressView("Saving…") }
        }
        .navigationTitle("Rename workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.disabled(store.isBusy)
            }
        }
        .interactiveDismissDisabled(store.isBusy)
    }
}
