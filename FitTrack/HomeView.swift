import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("FitTrack")
                .font(.largeTitle.bold())

            Text("Log your workouts, follow your progress, and find exercise alternatives when equipment is unavailable.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            NavigationLink(destination: ActiveWorkoutView()) {
                Text("Start Workout")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Home")
    }
}
