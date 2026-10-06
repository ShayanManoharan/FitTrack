import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isBenchPressRerouted = false
    @State private var isSaving = false
    @State private var saveMessage: String?

    private let firestoreService = FirestoreService()
    @State private var workoutStartedAt = Date()

    var body: some View {
        List {
            Section(header: Text("Upper Body Strength")) {
                exerciseRow(
                    isBenchPressRerouted ? "Dumbbell Floor Press" : "Barbell Bench Press",
                    details: isBenchPressRerouted
                        ? "3 sets × 8 reps · 30 lb per dumbbell"
                        : "3 sets × 8 reps · 95 lb"
                )
                exerciseRow("Seated Cable Row", details: "3 sets × 10 reps · 70 lb")
                exerciseRow("Dumbbell Shoulder Press", details: "3 sets × 10 reps · 20 lb per dumbbell")
            }

            Section(header: Text("Equipment unavailable?")) {
                Text(isBenchPressRerouted
                     ? "Bench press replaced with a dumbbell floor press. Sample weights are suggestions; adjust to your ability."
                     : "If the bench is busy, try a dumbbell floor press instead.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(isBenchPressRerouted ? "Restore Original Exercise" : "Reroute Exercise") {
                    isBenchPressRerouted.toggle()
                }
            }

            Section {
                Button {
                    saveWorkout()
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Save Workout")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSaving)

                if let saveMessage {
                    Text(saveMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Button("Back to Home") {
                    dismiss()
                }
            }
        }
        .navigationTitle("Active Workout")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("[Lifecycle] ActiveWorkoutView appeared")
        }
        .onDisappear {
            print("[Lifecycle] ActiveWorkoutView disappeared")
        }
    }

    private func saveWorkout() {
        isSaving = true
        saveMessage = nil

        let workoutID = UUID().uuidString
        let workout = Workout(
            workoutID: workoutID,
            userID: "demo-user",
            gymID: nil,
            date: Date(),
            duration: max(0, Int(Date().timeIntervalSince(workoutStartedAt))),
            workoutType: "Upper Body Strength",
            exercises: [
                WorkoutExercise(
                    workoutID: workoutID,
                    exerciseID: isBenchPressRerouted ? "dumbbell-floor-press" : "barbell-bench-press",
                    weight: isBenchPressRerouted ? 30 : 95,
                    reps: 8,
                    sets: 3
                ),
                WorkoutExercise(
                    workoutID: workoutID,
                    exerciseID: "seated-cable-row",
                    weight: 70,
                    reps: 10,
                    sets: 3
                ),
                WorkoutExercise(
                    workoutID: workoutID,
                    exerciseID: "dumbbell-shoulder-press",
                    weight: 20,
                    reps: 10,
                    sets: 3
                )
            ]
        )

        firestoreService.saveWorkout(workout) { result in
            DispatchQueue.main.async {
                isSaving = false

                switch result {
                case .success:
                    saveMessage = "Workout saved."
                case .failure(let error):
                    saveMessage = "Could not save workout: \(error.localizedDescription)"
                }
            }
        }
    }

    private func exerciseRow(_ name: String, details: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.headline)
            Text(details)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
