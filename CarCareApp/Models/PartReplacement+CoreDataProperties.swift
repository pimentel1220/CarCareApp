import Foundation
import CoreData

extension PartReplacement {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PartReplacement> {
        return NSFetchRequest<PartReplacement>(entityName: "PartReplacement")
    }

    @NSManaged public var id: UUID
    @NSManaged public var partName: String?
    @NSManaged public var linkedServiceLogID: UUID?
    @NSManaged public var date: Date
    @NSManaged public var mileage: Double
    @NSManaged public var intervalMonths: Int16
    @NSManaged public var intervalMiles: Double
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date

    @NSManaged public var vehicle: Vehicle?
}

extension PartReplacement: Identifiable {
}
