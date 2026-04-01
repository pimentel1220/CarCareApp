import Foundation

enum Formatters {
    static let mileage: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static func parseMileage(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let normalized = trimmed.replacingOccurrences(of: ",", with: "")
        return Double(normalized)
    }

    static func mileageText(_ value: Double) -> String {
        guard value > 0 else { return "" }
        return mileage.string(from: NSNumber(value: value)) ?? String(Int(value))
    }

    static func mileageLabel(_ value: Double) -> String {
        mileage.string(from: NSNumber(value: value)) ?? String(Int(value))
    }
}
