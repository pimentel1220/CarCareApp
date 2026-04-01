import Foundation

struct PartIntervalRecommendation {
    let intervalMonths: Int
    let intervalMiles: Int
}

enum PartIntervalRecommendations {
    static let defaults: [String: PartIntervalRecommendation] = [
        "oil": .init(intervalMonths: 6, intervalMiles: 5000),
        "engine air filter": .init(intervalMonths: 12, intervalMiles: 15000),
        "cabin air filter": .init(intervalMonths: 12, intervalMiles: 15000),
        "battery": .init(intervalMonths: 36, intervalMiles: 36000),
        "brake fluid": .init(intervalMonths: 24, intervalMiles: 24000),
        "coolant": .init(intervalMonths: 60, intervalMiles: 60000),
        "spark plug": .init(intervalMonths: 60, intervalMiles: 60000),
        "tire": .init(intervalMonths: 72, intervalMiles: 50000),
        "wiper": .init(intervalMonths: 12, intervalMiles: 0),
        "serpentine belt": .init(intervalMonths: 60, intervalMiles: 60000),
        "timing belt": .init(intervalMonths: 84, intervalMiles: 90000)
    ]

    static func recommendation(for partName: String) -> PartIntervalRecommendation? {
        let normalized = partName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        if let exact = defaults[normalized] {
            return exact
        }

        for (key, value) in defaults {
            if normalized.contains(key) {
                return value
            }
        }
        return nil
    }
}
