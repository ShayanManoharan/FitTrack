import Combine
import FirebaseAuth
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    enum State: Equatable {
        case signedOut
        case signedIn(AuthenticatedUser)
    }

    @Published private(set) var state: State = .signedOut
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let repository: AuthRepository

    init(repository: AuthRepository = AuthRepository()) {
        self.repository = repository
        state = repository.currentUser.map(State.signedIn) ?? .signedOut
        repository.observeAuthState { [weak self] user in
            Task { @MainActor in
                self?.state = user.map(State.signedIn) ?? .signedOut
            }
        }
    }

    var currentUser: AuthenticatedUser? {
        if case let .signedIn(user) = state {
            return user
        }
        return nil
    }

    func signUp(email: String, password: String, name: String? = nil) {
        authenticate(onSuccess: {
            // The existing Home greeting reads this local display-name preference.
            // Only update it after Firebase confirms account creation.
            if let name, !name.isEmpty {
                UserDefaults.standard.set(name.components(separatedBy: .whitespaces).first ?? name,
                                          forKey: "fittrack.native.displayName")
                if let user = self.repository.currentUser {
                    let profile = ProfileStore(user: user)
                    var settings = profile.settings
                    settings.name = name
                    profile.save(settings)
                }
            }
        }) { [repository] completion in
            repository.signUp(email: email, password: password, completion: completion)
        }
    }

    func signIn(email: String, password: String) {
        authenticate { [repository] completion in
            repository.signIn(email: email, password: password, completion: completion)
        }
    }

    func signOut() {
        do {
            try repository.signOut()
            errorMessage = nil
            state = .signedOut
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }

    deinit {
        repository.removeAuthStateObserver()
    }

    private func authenticate(
        onSuccess: (() -> Void)? = nil,
        _ operation: (@escaping (Result<AuthenticatedUser, Error>) -> Void) -> Void
    ) {
        isLoading = true
        errorMessage = nil
        operation { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                if case let .failure(error) = result {
                    self.errorMessage = error.localizedDescription
                } else {
                    onSuccess?()
                }
            }
        }
    }
}
