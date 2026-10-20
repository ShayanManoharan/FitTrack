import Foundation

struct AuthenticatedUser: Identifiable, Equatable {
    let id: String
    let email: String?
    let displayName: String?
}
