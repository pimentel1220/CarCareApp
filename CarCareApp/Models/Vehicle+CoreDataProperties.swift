import Foundation
import CoreData

extension Vehicle {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Vehicle> {
        return NSFetchRequest<Vehicle>(entityName: "Vehicle")
    }

    @NSManaged public var id: UUID
    @NSManaged public var nickname: String?
    @NSManaged public var make: String?
    @NSManaged public var model: String?
    @NSManaged public var year: Int16
    @NSManaged public var trim: String?
    @NSManaged public var engine: String?
    @NSManaged public var vin: String?
    @NSManaged public var plate: String?
    @NSManaged public var notes: String?
    @NSManaged public var photoData: Data?
    @NSManaged public var currentMileage: Double
    @NSManaged public var createdAt: Date

    @NSManaged public var logs: Set<ServiceLog>?
    @NSManaged public var reminders: Set<Reminder>?
    @NSManaged public var parts: Set<PartReplacement>?
}

extension Vehicle: Identifiable {
}

extension Vehicle {
    var displayName: String {
        if let nickname, !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nickname
        }
        let yearText = year > 0 ? String(year) : ""
        let makeText = make ?? ""
        let modelText = model ?? ""
        let combined = [yearText, makeText, modelText].filter { !$0.isEmpty }.joined(separator: " ")
        return combined.isEmpty ? "Vehicle" : combined
    }

    var sortedLogs: [ServiceLog] {
        let set = logs ?? []
        return set.sorted { $0.date > $1.date }
    }

    var sortedReminders: [Reminder] {
        let set = reminders ?? []
        return set.sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }
    }

    var sortedParts: [PartReplacement] {
        let set = parts ?? []
        return set.sorted { $0.date > $1.date }
    }

    var latestKnownMileage: Double {
        let logMax = sortedLogs.map(\.mileage).max() ?? 0
        let partMax = sortedParts.map(\.mileage).max() ?? 0
        return max(currentMileage, logMax, partMax)
    }

    func log(with id: UUID?) -> ServiceLog? {
        guard let id else { return nil }
        return sortedLogs.first { $0.id == id }
    }
}
