import Foundation

struct ProfileSettings: Codable, Equatable {
    var name: String
    var email: String
    var goal = "Build strength"
    var place = "Gym"
    var duration = "60"
    var units = "Pounds"
    var reminders = "On"
    var appearance = "System"
    var notifications = "On"
    // Optional fields keep profiles saved by earlier app versions decodable.
    var reminderHour: Int? = 9
    var reminderMinute: Int? = 0

    static let goals = ["Build strength", "Build muscle", "Improve endurance", "Stay active"]
    static let places = ["Gym", "Home", "Outdoors"]
    static let durations = ["30", "45", "60", "90"]
}
