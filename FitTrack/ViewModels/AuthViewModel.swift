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

    func signUp(email: String, password: String) {
        authenticate { [repository] completion in
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
                }
            }
        }
    }
}
