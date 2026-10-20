import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var store = WorkoutStore()

    var body: some View {
        Group {
            switch authViewModel.state {
            case .signedOut:
                LoginView()
            case .signedIn:
                MainControllerView(store: store)
                    .ignoresSafeArea(.container, edges: .bottom)
                    .preferredColorScheme(.light)
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                        store.persist()
                    }
            }
        }
    }
}