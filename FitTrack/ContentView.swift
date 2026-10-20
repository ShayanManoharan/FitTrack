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
    @ObservedObject var auth: AuthViewModel
    @StateObject private var store: WorkoutStore
    @StateObject private var profile: ProfileStore

    init(user: AuthenticatedUser, auth: AuthViewModel) {
        self.auth = auth
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
            .preferredColorScheme(.light)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                store.persist()
            }
    }
}
