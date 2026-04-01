import Foundation
import CoreData

extension Reminder {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Reminder> {
        return NSFetchRequest<Reminder>(entityName: "Reminder")
    }

    @NSManaged public var id: UUID
    @NSManaged public var title: String?
    @NSManaged public var details: String?
    @NSManaged public var dueDate: Date?
    @NSManaged public var dueMileage: Double
    @NSManaged public var lastServiceDate: Date?
    @NSManaged public var lastServiceMileage: Double
    @NSManaged public var repeatIntervalMonths: Int16
    @NSManaged public var repeatIntervalMiles: Double
    @NSManaged public var isCompleted: Bool
    @NSManaged public var notificationID: String?
    @NSManaged public var linkedServiceLogID: UUID?

    @NSManaged public var vehicle: Vehicle?
}

extension Reminder: Identifiable {
}

extension Reminder {
    var isTimeBased: Bool {
        dueDate != nil || repeatIntervalMonths > 0
    }

    var isMileageBased: Bool {
        dueMileage > 0 || repeatIntervalMiles > 0
    }
}
