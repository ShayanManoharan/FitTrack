import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isBenchPressRerouted = false

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
