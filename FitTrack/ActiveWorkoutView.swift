import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section(header: Text("Upper Body Strength")) {
                exerciseRow("Barbell Bench Press", details: "3 sets × 8 reps · 95 lb")
                exerciseRow("Seated Cable Row", details: "3 sets × 10 reps · 70 lb")
                exerciseRow("Dumbbell Shoulder Press", details: "3 sets × 10 reps · 20 lb per dumbbell")
            }

            Section {
                Button("Back to Home") {
                    dismiss()
                }
            }
        }
        .navigationTitle("Active Workout")
        .navigationBarTitleDisplayMode(.inline)
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
