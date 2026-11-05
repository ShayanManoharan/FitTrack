import Foundation

enum WeightUnit: String {
    case pounds = "Pounds", kilograms = "Kilograms"
    init(preference: String) { self = WeightUnit(rawValue: preference) ?? .pounds }
    var symbol: String { self == .pounds ? "lb" : "kg" }
    // Existing targets, cached sessions, and Firestore weights remain in pounds.
    func fromPounds(_ value: Double) -> Double { self == .pounds ? value : value * 0.45359237 }
    func toPounds(_ value: Double) -> Double { self == .pounds ? value : value / 0.45359237 }
    func editingValue(fromPounds value: Double) -> Double { (fromPounds(value) * 100).rounded() / 100 }
    func label(pounds: Double) -> String {
        "\(fromPounds(pounds).formatted(.number.precision(.fractionLength(0...2)))) \(symbol)"
    }
}
