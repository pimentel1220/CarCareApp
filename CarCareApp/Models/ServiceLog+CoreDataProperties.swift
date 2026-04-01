import Foundation
import CoreData

extension ServiceLog {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ServiceLog> {
        return NSFetchRequest<ServiceLog>(entityName: "ServiceLog")
    }

    @NSManaged public var id: UUID
    @NSManaged public var title: String?
    @NSManaged public var date: Date
    @NSManaged public var mileage: Double
    @NSManaged public var cost: Double
    @NSManaged public var shop: String?
    @NSManaged public var details: String?
    @NSManaged public var photoData: Data?
    @NSManaged public var createdAt: Date

    @NSManaged public var vehicle: Vehicle?
}

extension ServiceLog: Identifiable {
}
