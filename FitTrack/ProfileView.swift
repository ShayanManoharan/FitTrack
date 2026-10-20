import SwiftUI

struct ProfileView: View {
    @ObservedObject var profile: ProfileStore
    @ObservedObject var auth: AuthViewModel
    @State private var panel: ProfilePanel?
    @State private var savedNotice = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Profile").font(.system(size: 27, weight: .bold)).tracking(-0.8)
                        .padding(.bottom, 16).accessibilityAddTraits(.isHeader)
                    identity
                    if geometry.size.width > 700 {
                        HStack(alignment: .top, spacing: 26) {
                            preferences.frame(maxWidth: .infinity)
                            VStack(spacing: 0) { settings; account }.frame(maxWidth: .infinity)
                        }
                    } else { preferences; settings; account }
                    if let error = profile.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red).padding(.top, 14)
                    }
                }.padding(.horizontal, 21).padding(.top, 18).padding(.bottom, 25)
                    .frame(maxWidth: 1100).frame(maxWidth: .infinity)
            }.fitTrackScreen()
        }
        .overlay(alignment: .bottom) {
            if savedNotice {
                Text("Changes saved").font(.system(size: 13)).foregroundStyle(.white)
                    .padding(12).frame(maxWidth: .infinity).background(FitTrackStyle.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 11)).padding(22)
                    .accessibilityIdentifier("profileSavedNotice")
            }
        }
        .task(id: savedNotice) {
            if savedNotice {
                do { try await Task.sleep(for: .seconds(2.2)); savedNotice = false }
                catch { }
            }
        }
        .sheet(item: $panel) { selected in
            if selected == .signout {
                signOutPanel
            } else {
                ProfileEditorView(panel: selected, initial: profile.settings, signInEmail: auth.currentUser?.email ?? "", errorMessage: profile.errorMessage) { updated in
                    if profile.save(updated) {
                        panel = nil
                        savedNotice = true
                    }
                }
            }
        }
        .onAppear { profile.reload(); print("[Lifecycle] ProfileView appeared") }
        .onDisappear { print("[Lifecycle] ProfileView disappeared") }
    }

    private var identity: some View {
        HStack(spacing: 12) {
            Text(String(profile.settings.name.first ?? "F").uppercased())
                .font(.system(size: 20, weight: .heavy)).foregroundStyle(FitTrackStyle.accent)
                .frame(width: 48, height: 48).background(FitTrackStyle.pale).clipShape(Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.settings.name).font(.system(size: 17, weight: .bold))
                Text("FITTRACK member").font(.system(size: 12)).foregroundStyle(FitTrackStyle.muted)
            }
            Spacer()
        }.fitTrackCard()
    }

    private func heading(_ title: String) -> some View {
        Text(title.uppercased()).font(.system(size: 12, weight: .heavy)).tracking(1)
            .foregroundStyle(FitTrackStyle.muted).padding(.top, 20).padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
    }

    private var preferences: some View {
        VStack(spacing: 0) {
            heading("Preferences")
            VStack(spacing: 0) {
                row(.goals, symbol: "◎", title: "Fitness goals", detail: profile.settings.goal)
                Divider().overlay(FitTrackStyle.background)
                row(.workout, symbol: "▤", title: "Workout preferences", detail: "\(profile.settings.place) · \(profile.settings.duration) minutes")
                Divider().overlay(FitTrackStyle.background)
                row(.units, symbol: "⚖", title: "Units & reminders", detail: "\(profile.settings.units) · Reminders \(profile.settings.reminders.lowercased())")
            }.profileGroup()
        }
    }

    private var settings: some View {
        VStack(spacing: 0) {
            heading("Settings")
            VStack(spacing: 0) {
                row(.general, symbol: "⚙", title: "App settings", detail: "Appearance and notifications")
                Divider().overlay(FitTrackStyle.background)
                row(.account, symbol: "♙", title: "Account settings", detail: "Name and email")
            }.profileGroup()
        }
    }

    private var account: some View {
        VStack(spacing: 0) {
            heading("Account")
            row(.signout, symbol: "↪", title: "Sign out", detail: nil, destructive: true).profileGroup()
        }
    }

    private func row(_ selected: ProfilePanel, symbol: String, title: String, detail: String?, destructive: Bool = false) -> some View {
        Button {
            if selected == .signout { auth.clearError() }
            panel = selected
        } label: {
            HStack(spacing: 11) {
                Text(symbol).font(.system(size: 16)).frame(width: 29, height: 29)
                    .foregroundStyle(destructive ? Color(red: 0.65, green: 0.24, blue: 0.22) : FitTrackStyle.accent)
                    .background(destructive ? Color(red: 1, green: 0.94, blue: 0.94) : FitTrackStyle.pale)
                    .clipShape(RoundedRectangle(cornerRadius: 9)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .bold))
                        .foregroundStyle(destructive ? Color(red: 0.65, green: 0.24, blue: 0.22) : FitTrackStyle.ink)
                    if let detail { Text(detail).font(.system(size: 11)).foregroundStyle(FitTrackStyle.muted) }
                }
                Spacer()
                Text("›").font(.system(size: 21)).foregroundStyle(FitTrackStyle.tabMuted).accessibilityHidden(true)
            }.padding(.horizontal, 15).padding(.vertical, 13).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("profile.\(selected.rawValue)")
    }

    private var signOutPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sign out?").font(.system(size: 21, weight: .bold)).accessibilityAddTraits(.isHeader)
            Text("You'll return to the sign-in page. Your saved plans, workout progress, and preferences remain on this device for this account.")
                .font(.system(size: 13)).foregroundStyle(FitTrackStyle.muted)
            if let error = auth.errorMessage { Text(error).font(.footnote).foregroundStyle(.red) }
            Button("Sign out") { auth.signOut() }.buttonStyle(FitTrackPrimary())
                .accessibilityIdentifier("confirmSignOut")
            Button("Cancel") { panel = nil }.buttonStyle(FitTrackOutline())
        }.padding(22).fitTrackScreen()
            .presentationDetents([.height(310), .medium]).presentationDragIndicator(.visible)
    }
}

private enum ProfilePanel: String, Identifiable {
    case goals, workout, units, general, account, signout
    var id: String { rawValue }
    var title: String {
        switch self {
        case .goals: "Fitness goals"
        case .workout: "Workout preferences"
        case .units: "Units & reminders"
        case .general: "App settings"
        case .account: "Account settings"
        case .signout: "Sign out"
        }
    }
}

private struct ProfileEditorView: View {
    let panel: ProfilePanel
    let signInEmail: String
    let errorMessage: String?
    let onSave: (ProfileSettings) -> Void
    @State private var draft: ProfileSettings
    @Environment(\.dismiss) private var dismiss

    init(panel: ProfilePanel, initial: ProfileSettings, signInEmail: String, errorMessage: String?, onSave: @escaping (ProfileSettings) -> Void) {
        self.panel = panel
        self.signInEmail = signInEmail
        self.errorMessage = errorMessage
        self.onSave = onSave
        _draft = State(initialValue: initial)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(panel.title).font(.system(size: 21, weight: .bold)).accessibilityAddTraits(.isHeader)
                switch panel {
                case .goals:
                    choice("Primary goal", selection: $draft.goal, options: ProfileSettings.goals)
                case .workout:
                    choice("Workout location", selection: $draft.place, options: ProfileSettings.places)
                    choice("Preferred duration", selection: $draft.duration, options: ProfileSettings.durations)
                case .units:
                    choice("Weight units", selection: $draft.units, options: ["Pounds", "Kilograms"])
                    choice("Workout reminders", selection: $draft.reminders, options: ["On", "Off"])
                    note("These preferences are saved locally. Workout weight conversion and scheduled reminders are not connected yet.")
                case .general:
                    choice("Appearance", selection: $draft.appearance, options: ["System", "Light", "Dark"])
                    choice("Notifications", selection: $draft.notifications, options: ["On", "Off"])
                    note("These choices are saved on this device. Appearance and notifications need app integration to take effect.")
                case .account:
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name").font(.system(size: 12, weight: .semibold))
                        TextField("Name", text: $draft.name).textContentType(.name).textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Profile email").font(.system(size: 12, weight: .semibold))
                        TextField("Email", text: $draft.email).keyboardType(.emailAddress).textContentType(.emailAddress)
                            .textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                    }
                    note("Name and profile email are saved on this device. Your Firebase sign-in email remains \(signInEmail).")
                case .signout: EmptyView()
                }
                if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
                Button("Save changes") { onSave(draft) }.buttonStyle(FitTrackPrimary())
                    .disabled(!validAccount).accessibilityIdentifier("saveProfileChanges")
                Button("Cancel") { dismiss() }.buttonStyle(FitTrackOutline())
            }.padding(22)
        }.fitTrackScreen().presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }

    private var validAccount: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.name.count <= 60
        && draft.email.contains("@") && !draft.email.contains(where: \.isWhitespace)
    }
    private func note(_ text: String) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(FitTrackStyle.muted)
    }
    private func choice(_ title: String, selection: Binding<String>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 12, weight: .semibold))
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                .padding(5).background(.white)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(FitTrackStyle.line))
        }
    }
}

private extension View {
    func profileGroup() -> some View {
        background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: FitTrackStyle.ink.opacity(0.04), radius: 7, y: 3)
    }
}
