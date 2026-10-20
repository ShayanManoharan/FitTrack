import Foundation
import Testing
@testable import FitTrack

@MainActor
struct ProfileStoreTests {
    @Test func preferencesPersistAndStaySeparateByAccount() throws {
        let suite = "ProfileTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let user = AuthenticatedUser(id: "one", email: "one@example.com", displayName: "First User")
        let store = ProfileStore(user: user, defaults: defaults)
        var edit = store.settings
        edit.name = "Updated Name"
        edit.goal = "Build muscle"
        edit.units = "Kilograms"
        #expect(store.save(edit))
        #expect(ProfileStore(user: user, defaults: defaults).settings == edit)
        let other = ProfileStore(user: AuthenticatedUser(id: "two", email: "two@example.com", displayName: nil), defaults: defaults)
        #expect(other.settings.name == "two")
        #expect(other.settings.goal == "Build strength")
        #expect(other.settings.units == "Pounds")
    }

    @Test func invalidEditsDoNotReplaceSavedProfile() throws {
        let suite = "ProfileTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ProfileStore(user: AuthenticatedUser(id: "one", email: "one@example.com", displayName: "First"), defaults: defaults)
        let original = store.settings
        var edit = original
        edit.name = " "
        #expect(!store.save(edit))
        #expect(store.settings == original)
        edit.name = "Valid"
        edit.email = "invalid"
        #expect(!store.save(edit))
        #expect(store.settings == original)
    }
}
