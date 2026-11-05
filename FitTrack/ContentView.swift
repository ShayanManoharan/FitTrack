import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        Group {
            switch authViewModel.state {
            case .signedOut:
                LoginView()
            case .signedIn(let user):
                SignedInContentView(user: user, auth: authViewModel)
                    .id(user.id)
            }
        }
    }
}

private struct SignedInContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var activation = 0
    @ObservedObject private var reminders = WorkoutReminderService.shared
    private let userID: String
    @ObservedObject var auth: AuthViewModel
    @StateObject private var store: WorkoutStore
    @StateObject private var profile: ProfileStore

    init(user: AuthenticatedUser, auth: AuthViewModel) {
        self.auth = auth
        self.userID = user.id
        // Keep one account's local draft/plans out of another account's session.
        let defaults = UserDefaults(suiteName: "fittrack.workouts.\(user.id)") ?? .standard
        // Preserve the previous single-account cache once, then isolate accounts.
        let legacy = UserDefaults.standard
        let ownerKey = "fittrack.native.state.owner"
        if legacy.string(forKey: ownerKey) == nil,
           let data = legacy.data(forKey: "fittrack.native.state") {
            legacy.set(user.id, forKey: ownerKey)
            if defaults.data(forKey: "fittrack.native.state") == nil {
                defaults.set(data, forKey: "fittrack.native.state")
            }
        }
        _store = StateObject(wrappedValue: WorkoutStore(defaults: defaults))
        _profile = StateObject(wrappedValue: ProfileStore(user: user))
    }

    var body: some View {
        MainControllerView(store: store, profile: profile, auth: auth)
            .ignoresSafeArea(.container, edges: .bottom)
            .preferredColorScheme(FitTrackStyle.colorScheme(profile.settings.appearance))

            .task(id: WorkoutReminderService.SyncKey(userID: userID, schedules: store.scheduledWorkouts,
                settings: profile.settings, permissionRequest: profile.reminderPermissionRequest, activation: activation)) {
                await reminders.synchronize(WorkoutReminderService.SyncKey(userID: userID, schedules: store.scheduledWorkouts,
                    settings: profile.settings, permissionRequest: profile.reminderPermissionRequest, activation: activation))
            }
            .onChange(of: auth.currentUser, initial: true) { _, user in
                if let user { profile.synchronizeAccount(user) }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    activation += 1
                    Task { await auth.refreshAccount() }
                }
            }
            .onDisappear { reminders.cancel(userID: userID) }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                store.persist()
            }
    }
}
