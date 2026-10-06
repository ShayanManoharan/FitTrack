import Foundation

struct User: Identifiable, Codable {
    var id: String { userID }

    let userID: String
    var name: String
    var email: String
    var preferences: String
}
