import FirebaseAuth

enum AuthRepositoryError: LocalizedError {
    case missingAuthenticatedUser

    var errorDescription: String? {
        switch self {
        case .missingAuthenticatedUser:
            return "No authenticated Firebase user is available."
        }
    }
}

final class AuthRepository {
    private let auth: Auth
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init(auth: Auth = Auth.auth()) {
        self.auth = auth
    }

    var currentUser: AuthenticatedUser? {
        auth.currentUser.map(Self.makeUser)
    }

    @discardableResult
    func observeAuthState(_ handler: @escaping (AuthenticatedUser?) -> Void) -> AuthStateDidChangeListenerHandle {
        let handle = auth.addStateDidChangeListener { _, user in
            handler(user.map(Self.makeUser))
        }
        authStateHandle = handle
        return handle
    }

    func removeAuthStateObserver() {
        if let authStateHandle {
            auth.removeStateDidChangeListener(authStateHandle)
            self.authStateHandle = nil
        }
    }

    func signUp(email: String, password: String, completion: @escaping (Result<AuthenticatedUser, Error>) -> Void) {
        auth.createUser(withEmail: email, password: password) { result, error in
            completion(Self.result(for: result?.user, error: error))
        }
    }

    func signIn(email: String, password: String, completion: @escaping (Result<AuthenticatedUser, Error>) -> Void) {
        auth.signIn(withEmail: email, password: password) { result, error in
            completion(Self.result(for: result?.user, error: error))
        }
    }

    func updateName(_ name: String) async throws -> AuthenticatedUser {
        guard let user = auth.currentUser else { throw AuthRepositoryError.missingAuthenticatedUser }
        let change = user.createProfileChangeRequest()
        change.displayName = name
        try await change.commitChanges()
        return Self.makeUser(user)
    }

    func requestEmailChange(to email: String, password: String) async throws {
        guard let user = auth.currentUser, let currentEmail = user.email else {
            throw AuthRepositoryError.missingAuthenticatedUser
        }
        let credential = EmailAuthProvider.credential(withEmail: currentEmail, password: password)
        try await user.reauthenticate(with: credential)
        try await user.sendEmailVerification(beforeUpdatingEmail: email)
    }

    func reloadUser() async throws -> AuthenticatedUser? {
        guard let user = auth.currentUser else { return nil }
        try await user.reload()
        return auth.currentUser.map(Self.makeUser)
    }

    func signOut() throws {
        try auth.signOut()
    }

    deinit {
        removeAuthStateObserver()
    }

    private static func makeUser(_ user: FirebaseAuth.User) -> AuthenticatedUser {
        AuthenticatedUser(id: user.uid, email: user.email, displayName: user.displayName)
    }

    private static func result(
        for user: FirebaseAuth.User?,
        error: Error?
    ) -> Result<AuthenticatedUser, Error> {
        if let error {
            return .failure(error)
        }
        guard let user else {
            return .failure(AuthRepositoryError.missingAuthenticatedUser)
        }
        return .success(makeUser(user))
    }
}
