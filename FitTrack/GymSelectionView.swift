import SwiftUI

struct GymSelectionView: View {
    @ObservedObject var store: WorkoutStore
    @StateObject private var location = LocationService()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    private var gyms: [NearbyGym] { GymDiscovery.ranked(WorkoutStore.gyms, from: location.location) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Choose a campus gym for your workouts. Use your location to sort these three gyms nearest-first, or choose manually.")
                    .font(.subheadline).foregroundStyle(FitTrackStyle.muted)
                locationControls
                ForEach(gyms) { nearby in
                    Button {
                        store.selectGym(nearby.id)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(nearby.gym.name).font(.headline)
                                Text(nearby.gym.address).font(.caption).foregroundStyle(FitTrackStyle.muted)
                                if let distance = nearby.distanceLabel {
                                    Text(distance).font(.subheadline.bold()).foregroundStyle(FitTrackStyle.accent)
                                }
                            }
                            Spacer()
                            if store.gymID == nearby.id { Image(systemName: "checkmark") }
                        }.fitTrackCard()
                    }.accessibilityValue(store.gymID == nearby.id ? "Selected" : "Not selected")
                }
                Text("Distances are approximate straight-line distances to campus buildings, not walking or driving directions.")
                    .font(.caption).foregroundStyle(FitTrackStyle.muted)
                Link("Gym locations © OpenStreetMap contributors", destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                    .font(.caption)
            }.padding(22)
        }
        .navigationTitle("Find gyms")
        .navigationBarTitleDisplayMode(.inline)
        .fitTrackScreen()
        .onAppear { location.refreshAuthorization() }
        .onDisappear { location.cancel() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { location.refreshAuthorization() }
            else if phase == .background { location.cancel() }
        }
    }

    @ViewBuilder private var locationControls: some View {
        if location.isLoading {
            ProgressView("Getting your location…")
            Button("Continue without location", action: location.cancel)
                .font(.subheadline)
        } else {
            switch location.status {
            case .denied:
                Text("Location access is off. Allow FitTrack location access in Settings and ensure Location Services is on, or choose a gym manually.")
                    .font(.subheadline).foregroundStyle(FitTrackStyle.muted)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }.buttonStyle(FitTrackOutline())
            case .restricted:
                Text("Location access is restricted on this device. Choose a gym manually.")
                    .font(.subheadline).foregroundStyle(FitTrackStyle.muted)
            default:
                if case .unavailable(let message) = location.status {
                    Text(message).font(.subheadline).foregroundStyle(FitTrackStyle.muted)
                }
                Button(location.location == nil ? "Use My Location" : "Refresh Location", action: location.requestLocation)
                    .buttonStyle(FitTrackOutline())
                    .accessibilityIdentifier("useGymLocation")
            }
        }
    }
}
