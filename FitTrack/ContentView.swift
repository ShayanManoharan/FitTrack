import SwiftUI

struct ContentView: View {
    @StateObject private var store = WorkoutStore()
    var body: some View {
        MainControllerView(store: store)
            .ignoresSafeArea(.container, edges: .bottom)
            .preferredColorScheme(.light)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                store.persist()
            }
    }
}
