import SwiftUI

struct ActiveWorkoutView: View {
    @ObservedObject var store: WorkoutStore
    let onHome: () -> Void
    @State private var showAlternatives = false
    @State private var showEditor = false
    @State private var confirmSkip = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if let session = store.session {
                    if session.finishedAt != nil {
                        completion(session).padding(22)
                    } else if let exercise = session.currentExercise {
                        Group {
                            if geometry.size.width > 700 {
                                HStack(alignment: .top, spacing: 34) {
                                    overview(session, exercise).frame(maxWidth: .infinity, alignment: .leading)
                                    setsAndActions(session, exercise).frame(maxWidth: .infinity, alignment: .leading)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 24) {
                                    overview(session, exercise)
                                    setsAndActions(session, exercise)
                                }
                            }
                        }.padding(22).frame(maxWidth: 1100).frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(spacing: 16) {
                        Text("Ready for your workout?").font(.title2.bold())
                        Button("START WORKOUT →") { store.startWorkout() }.buttonStyle(FitTrackPrimary())
                        Button("Back to Home", action: onHome)
                    }.padding(22)
                }
            }.fitTrackScreen()
        }
        .onAppear {
            print("[Lifecycle] ActiveWorkoutView appeared")
        }
        .onDisappear {
            print("[Lifecycle] ActiveWorkoutView disappeared")
        }
        .sheet(isPresented: $showAlternatives) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Choose a similar exercise when equipment is occupied or unavailable.")
                            .font(.subheadline).foregroundStyle(FitTrackStyle.muted)
                        if let exercise = store.session?.currentExercise {
                            let choices = WorkoutCatalog.alternatives(for: exercise)
                            if choices.isEmpty { Text("No alternatives are available for this custom exercise.") }
                            ForEach(choices) { alternative in
                                Button {
                                    store.replaceExercise(with: alternative)
                                    showAlternatives = false
                                } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(alternative.name).font(.headline)
                                        Text("\(alternative.muscleGroup) · \(alternative.equipment)")
                                            .font(.caption).foregroundStyle(FitTrackStyle.muted)
                                    }.frame(maxWidth: .infinity, alignment: .leading).fitTrackCard()
                                }
                            }
                            Text("Suggested weights are starting targets; adjust them to your ability. Replacing an exercise resets its checked sets.")
                                .font(.caption).foregroundStyle(FitTrackStyle.muted)
                        }
                    }.padding(22)
                }.navigationTitle("Find an alternative").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showAlternatives = false } } }
                    .fitTrackScreen()
            }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEditor) {
            if let exercise = store.session?.currentExercise {
                SetEditorView(sets: exercise.sets) { store.editSets($0) }
            }
        }
        .alert("Skip \(store.session?.currentExercise?.name ?? "exercise")?", isPresented: $confirmSkip) {
            Button("Skip exercise", role: .destructive) { store.skipExercise() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This exercise will be marked as skipped and you will move forward. Completed sets will remain recorded.") }
    }

    private func overview(_ session: WorkoutSession, _ exercise: SessionExercise) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onHome) { Label("ACTIVE WORKOUT", systemImage: "chevron.left") }
                .font(.system(size: 12, weight: .bold)).frame(minHeight: 44)
            VStack(alignment: .leading, spacing: 6) {
                    Text(session.name).font(.system(size: 27, weight: .bold)).tracking(-0.8)
                Text("\(session.exercises.count) exercises in this workout")
                    .font(.system(size: 14)).foregroundStyle(FitTrackStyle.muted)
            }
            HStack(spacing: 6) {
                ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, item in
                    Capsule().fill(item.isSkipped ? Color.orange : index <= session.currentIndex ? FitTrackStyle.accent : FitTrackStyle.line)
                        .frame(height: 5)
                }
            }.padding(.vertical, 6).accessibilityLabel("Exercise \(session.currentIndex + 1) of \(session.exercises.count)")
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "Exercise \(session.currentIndex + 1) of \(session.exercises.count)")
                    Text(exercise.name).font(.system(size: 24, weight: .bold)).tracking(-0.5)
                    Text("\(exercise.muscleGroup) · \(exercise.equipment)").font(.system(size: 12))
                        .foregroundStyle(FitTrackStyle.muted)
                }
                Spacer(minLength: 4)
                StatusPill(text: "In progress")
            }
        }
    }

    private func setsAndActions(_ session: WorkoutSession, _ exercise: SessionExercise) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Planned sets").font(.system(size: 16, weight: .bold))
                Spacer()
                Button("Edit details") { showEditor = true }.font(.system(size: 13, weight: .bold)).frame(minHeight: 44)
            }
            VStack(spacing: 0) {
                HStack {
                    Text("Done").frame(width: 44, alignment: .leading)
                    Text("Weight").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Reps").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Rest").frame(maxWidth: .infinity, alignment: .leading)
                }.textCase(.uppercase).font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FitTrackStyle.muted).padding(12).background(FitTrackStyle.background)
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                    Divider()
                    HStack {
                        Button { store.completeSet(set.id) } label: {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(set.isComplete ? FitTrackStyle.accent : .white)
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(set.isComplete ? FitTrackStyle.accent : FitTrackStyle.line, lineWidth: 2))
                                .overlay { if set.isComplete { Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white) } }
                                .frame(width: 22, height: 22).frame(width: 40, height: 54, alignment: .leading)
                        }.accessibilityLabel("Set \(index + 1)")
                            .accessibilityValue(set.isComplete ? "Complete" : "Incomplete")
                            .accessibilityHint("Toggle set completion")
                        Text("\(set.weight.formatted()) lb").frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(set.reps)").frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(set.rest) sec").frame(maxWidth: .infinity, alignment: .leading)
                    }.font(.system(size: 14)).padding(.horizontal, 16)
                        .foregroundStyle(set.isComplete ? FitTrackStyle.muted : FitTrackStyle.ink)
                }
            }.background(.white).clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: FitTrackStyle.ink.opacity(0.04), radius: 7, y: 3)
            Text("Check each set when you finish it. Your plan sets the targets based on your goals.")
                .font(.system(size: 12)).foregroundStyle(FitTrackStyle.muted)
            HStack(spacing: 12) {
                Button("↔ Find alternative") { showAlternatives = true }.buttonStyle(FitTrackOutline(height: 49))
                Button("Skip exercise →") { confirmSkip = true }
                    .buttonStyle(FitTrackOutline(height: 49, color: FitTrackStyle.muted))
            }.padding(.top, 13)
            Button(session.currentIndex == session.exercises.count - 1 ? "FINISH WORKOUT" : "COMPLETE EXERCISE →") {
                store.advanceExercise()
            }.buttonStyle(FitTrackPrimary(height: 54, radius: 14)).disabled(!session.canAdvance).padding(.top, 14)
            Text(session.canAdvance ? "All sets complete · ready to continue" : "Complete every set to continue")
                .font(.system(size: 12)).foregroundStyle(FitTrackStyle.muted).frame(maxWidth: .infinity)
        }
    }

    private func completion(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(FitTrackStyle.accent)
            Text("Workout complete!").font(.title.bold())
            Text("\(session.name) · \(session.completedCount) of \(session.exercises.count) exercises completed")
                .foregroundStyle(FitTrackStyle.muted)
            Text("\(session.exercises.filter(\.isSkipped).count) skipped · \(session.exercises.flatMap(\.sets).filter(\.isComplete).count) sets logged")
            Button(action: store.saveWorkout) {
                if store.isSaving { ProgressView().tint(.white) }
                else { Text(store.isSaved ? "WORKOUT SAVED" : "SAVE WORKOUT") }
            }.buttonStyle(FitTrackPrimary()).disabled(store.isSaving || store.isSaved)
            if let message = store.saveMessage { Text(message).font(.footnote).accessibilityAddTraits(.updatesFrequently) }
            Button("BACK TO HOME", action: onHome).buttonStyle(FitTrackOutline())
        }.fitTrackCard().frame(maxWidth: 600).frame(maxWidth: .infinity)
    }
}

private struct SetEditorView: View {
    @State var sets: [PlannedSet]
    let onSave: ([PlannedSet]) -> Void
    @Environment(\.dismiss) private var dismiss
    private var valid: Bool {
        sets.allSatisfy { $0.weight.isFinite && $0.weight >= 0 && $0.reps > 0 && $0.rest >= 0 }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Adjust targets for this exercise. Changes apply to this workout.")
                        .font(.subheadline).foregroundStyle(FitTrackStyle.muted)
                    ForEach($sets) { $set in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Set \((sets.firstIndex(where: { $0.id == set.id }) ?? 0) + 1)").font(.headline)
                            HStack {
                                VStack { Text("Weight (lb)"); TextField("Weight", value: $set.weight, format: .number).keyboardType(.decimalPad) }
                                VStack { Text("Reps"); TextField("Reps", value: $set.reps, format: .number).keyboardType(.numberPad) }
                                VStack { Text("Rest (sec)"); TextField("Rest", value: $set.rest, format: .number).keyboardType(.numberPad) }
                            }.font(.caption).textFieldStyle(.roundedBorder)
                        }.fitTrackCard()
                    }
                    Button("SAVE CHANGES") { onSave(sets); dismiss() }.buttonStyle(FitTrackPrimary()).disabled(!valid)
                }.padding(22)
            }.navigationTitle("Edit planned sets").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .fitTrackScreen()
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}
