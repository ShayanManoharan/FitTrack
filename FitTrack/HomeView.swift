import SwiftUI

struct HomeView: View {
    @ObservedObject var store: WorkoutStore
    let onStartWorkout: () -> Void
    @State private var sheet: HomeSheet?
    @AppStorage("fittrack.native.displayName") private var displayName = "Kevin"

    private enum HomeSheet: String, Identifiable {
        case gyms, plans, create
        var id: String { rawValue }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if geometry.size.width > 700 {
                        HStack(alignment: .top, spacing: 24) {
                            VStack(spacing: 18) { gym; planActions }.frame(maxWidth: .infinity)
                            todayWorkout.frame(maxWidth: .infinity)
                        }
                    } else { gym; todayWorkout; planActions }
                    if let message = store.storageMessage {
                        Text(message).font(.footnote).foregroundStyle(.red)
                    }
                }.padding(.horizontal, 21).padding(.top, 16).padding(.bottom, 12)
                    .frame(maxWidth: 1100).frame(maxWidth: .infinity)
            }.fitTrackScreen()
        }
        .onAppear {
            print("[Lifecycle] HomeView appeared")
        }
        .onDisappear {
            print("[Lifecycle] HomeView disappeared")
        }
        .sheet(item: $sheet) { route in
            NavigationStack {
                Group {
                    switch route {
                    case .gyms: gymChoices
                    case .plans: SavedPlansView(store: store, onStart: onStartWorkout)
                    case .create: PlanEditorView(store: store, plan: nil)
                    }
                }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { sheet = nil } } }
            }.tint(FitTrackStyle.accent).preferredColorScheme(.light)
                .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FITTRACK").font(.system(size: 12, weight: .heavy)).tracking(1.4)
                .foregroundStyle(FitTrackStyle.accent).padding(.bottom, 9)
            HStack {
                Text("Hi, \(displayName)").font(.system(size: 26, weight: .bold)).tracking(-0.7)
                Spacer()
                Text("🔥 \(store.streak)-day streak").font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color(red: 0.53, green: 0.32, blue: 0.09))
                    .padding(.horizontal, 11).padding(.vertical, 8)
                    .background(Color(red: 1, green: 0.94, blue: 0.86)).clipShape(Capsule())
            }
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(size: 12)).foregroundStyle(FitTrackStyle.muted)
        }
    }

    private var gym: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current gym").font(.system(size: 16, weight: .bold))
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow(text: "Your location")
                    Text(store.gymName).font(.system(size: 18, weight: .bold))
                    Text("Columbus, OH").font(.system(size: 12)).foregroundStyle(FitTrackStyle.muted)
                }
                Spacer()
                Button("Find gyms →") { sheet = .gyms }
                    .font(.system(size: 12, weight: .bold)).padding(10)
                    .background(FitTrackStyle.pale).clipShape(RoundedRectangle(cornerRadius: 10))
            }.fitTrackCard()
        }
    }

    private var todayWorkout: some View {
        let session = store.session
        let title = store.hasPendingSession ? session?.name ?? store.todayPlan.name : store.todayPlan.name
        let total = store.hasPendingSession ? session?.exercises.count ?? 0 : store.todayPlan.exercises.count
        let done = store.hasPendingSession ? session?.completedCount ?? 0 : 0
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's workout").font(.system(size: 16, weight: .bold))
                Spacer()
                Text(Date.now.formatted(.dateTime.month(.abbreviated).day())).font(.system(size: 12))
                    .foregroundStyle(FitTrackStyle.muted)
            }
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    Text(title).font(.system(size: 19, weight: .bold))
                    Spacer()
                    StatusPill(text: store.hasActiveSession ? "In progress" : store.hasPendingSession ? "Ready to save" : "Scheduled")
                }
                HStack(spacing: 8) {
                    detail("Time", value: "—")
                    detail("Location", value: store.gymName)
                }
                detail("Exercises", value: "\(done) of \(total) completed · \(total) planned")
                Button(store.hasActiveSession ? "RESUME WORKOUT →" : store.hasPendingSession ? "SAVE FINISHED WORKOUT →" : "START WORKOUT →") {
                    store.startWorkout()
                    onStartWorkout()
                }.buttonStyle(FitTrackPrimary()).disabled(store.isSaving)
            }.fitTrackCard()
        }
    }

    private func detail(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 10)).foregroundStyle(FitTrackStyle.muted)
            Text(value).font(.system(size: 13, weight: .semibold))
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
            .background(FitTrackStyle.detail).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var planActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Workout plans").font(.system(size: 16, weight: .bold))
                Spacer()
                Button("View all →") { sheet = .plans }.font(.system(size: 12, weight: .bold))
            }
            Button("＋ Create workout plan") { sheet = .create }.buttonStyle(FitTrackOutline())
            Text(store.plans.last.map { "\($0.name) · \($0.exercises.count) exercises · \(store.plans.count) plans saved" }
                 ?? "No plans saved yet.")
                .font(.system(size: 12)).foregroundStyle(FitTrackStyle.muted)
        }
    }

    private var gymChoices: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Choose a gym to use for your workouts. These are sample locations; nearby search is not connected.")
                    .font(.subheadline).foregroundStyle(FitTrackStyle.muted)
                ForEach(WorkoutStore.gyms, id: \.id) { gym in
                    Button { store.selectGym(gym.id); sheet = nil } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(gym.name).font(.headline)
                                Text("Columbus, OH").font(.caption).foregroundStyle(FitTrackStyle.muted)
                            }
                            Spacer()
                            if store.gymID == gym.id { Image(systemName: "checkmark") }
                        }.fitTrackCard()
                    }
                }
            }.padding(22)
        }.navigationTitle("Find gyms").navigationBarTitleDisplayMode(.inline).fitTrackScreen()
    }
}
