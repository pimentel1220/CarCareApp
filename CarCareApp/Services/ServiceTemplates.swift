import Foundation

struct ServiceTemplate: Identifiable {
    let id = UUID()
    let name: String
    let intervalMiles: Double
    let intervalMonths: Int
    let notes: String
}

enum ServiceTemplates {
    static let all: [ServiceTemplate] = [
        ServiceTemplate(name: "Oil Change", intervalMiles: 5000, intervalMonths: 6, notes: "Typical interval; adjust for your vehicle."),
        ServiceTemplate(name: "Tire Rotation", intervalMiles: 6000, intervalMonths: 6, notes: "Rotate with oil change for even wear."),
        ServiceTemplate(name: "Brake Inspection", intervalMiles: 12000, intervalMonths: 12, notes: "Inspect pads/rotors and hydraulic system."),
        ServiceTemplate(name: "Brake Pads/Rotors", intervalMiles: 35000, intervalMonths: 36, notes: "Replacement varies by driving style, weight, and terrain."),
        ServiceTemplate(name: "Engine Air Filter", intervalMiles: 15000, intervalMonths: 12, notes: "Replace if dirty; dusty areas may need sooner."),
        ServiceTemplate(name: "Cabin Air Filter", intervalMiles: 15000, intervalMonths: 12, notes: "Replace yearly for HVAC performance."),
        ServiceTemplate(name: "Brake Fluid", intervalMiles: 24000, intervalMonths: 24, notes: "Check moisture level; follow manufacturer spec."),
        ServiceTemplate(name: "Transmission Fluid", intervalMiles: 60000, intervalMonths: 60, notes: "Many modern automatics use longer intervals; severe use may need earlier service."),
        ServiceTemplate(name: "Coolant", intervalMiles: 60000, intervalMonths: 60, notes: "Long-life coolant varies by make."),
        ServiceTemplate(name: "Power Steering Fluid", intervalMiles: 50000, intervalMonths: 48, notes: "Applicable on hydraulic systems (not electric power steering)."),
        ServiceTemplate(name: "Spark Plugs", intervalMiles: 60000, intervalMonths: 60, notes: "Interval varies by engine type."),
        ServiceTemplate(name: "Battery", intervalMiles: 36000, intervalMonths: 36, notes: "Test yearly after year 3."),
        ServiceTemplate(name: "Alignment", intervalMiles: 12000, intervalMonths: 12, notes: "Check at least yearly or when tire wear/drift appears."),
        ServiceTemplate(name: "Fuel System Service", intervalMiles: 30000, intervalMonths: 24, notes: "Injector/intake cleaning intervals vary by fuel quality and engine type."),
        ServiceTemplate(name: "Belts & Hoses", intervalMiles: 60000, intervalMonths: 48, notes: "Inspect regularly; replace earlier if cracked, swollen, or noisy."),
        ServiceTemplate(name: "AC Service", intervalMiles: 0, intervalMonths: 24, notes: "Performance/leak check every 2 years or when cooling drops."),
        ServiceTemplate(name: "Inspection", intervalMiles: 0, intervalMonths: 12, notes: "Annual safety inspection."),
    ]

    static let popularServiceTypes: [String] = [
        "Oil Change",
        "Tire Rotation",
        "Brake Inspection",
        "Brake Pads/Rotors",
        "Brake Fluid",
        "Transmission Fluid",
        "Coolant",
        "Power Steering Fluid",
        "Engine Air Filter",
        "Cabin Air Filter",
        "Spark Plugs",
        "Battery",
        "Alignment",
        "Tire Replacement",
        "Fuel System Service",
        "Belts & Hoses",
        "AC Service",
        "Inspection",
        "Detailing",
        "Custom"
    ]
}
