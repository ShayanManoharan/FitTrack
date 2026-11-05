import Combine
import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var settings: ProfileSettings
    @Published private(set) var errorMessage: String?
    @Published private(set) var reminderPermissionRequest = 0
    private let defaults: UserDefaults
    private let key: String

    init(user: AuthenticatedUser, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        key = "fittrack.profile.\(user.id)"
        let fallback = user.displayName.flatMap { $0.isEmpty ? nil : $0 }
            ?? user.email?.components(separatedBy: "@").first ?? "FITTRACK member"
        settings = ProfileSettings(name: fallback, email: user.email ?? "")
        if let data = defaults.data(forKey: key) {
            do { settings = try JSONDecoder().decode(ProfileSettings.self, from: data) }
            catch { errorMessage = "Could not read saved preferences. \(error.localizedDescription)" }
        }
        updateGreeting()
    }

    @discardableResult
    func save(_ updated: ProfileSettings, requestReminderPermission: Bool = false) -> Bool {
        var updated = updated
        updated.name = updated.name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.email = updated.email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !updated.name.isEmpty, updated.name.count <= 60,
              updated.email.contains("@"), !updated.email.contains(where: \.isWhitespace) else {
            errorMessage = "Enter a name and valid profile email."
            return false
        }
        do {
            let data = try JSONEncoder().encode(updated)
            defaults.set(data, forKey: key)
            settings = updated
            errorMessage = nil
            updateGreeting()
            if requestReminderPermission && updated.reminders == "On" && updated.notifications == "On" {
                reminderPermissionRequest += 1
            }
            return true
        } catch {
            errorMessage = "Could not save preferences: \(error.localizedDescription)"
            return false
        }
    }

    func synchronizeAccount(_ user: AuthenticatedUser) {
        var updated = settings
        if let name = user.displayName, !name.isEmpty { updated.name = name }
        if let email = user.email { updated.email = email }
        if updated != settings { save(updated) }
    }

    func reload() {
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONDecoder().decode(ProfileSettings.self, from: data), saved != settings else { return }
        settings = saved
        updateGreeting()
    }

    private func updateGreeting() {
        let firstName = settings.name.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? settings.name
        defaults.set(firstName, forKey: "fittrack.native.displayName")
    }
}
