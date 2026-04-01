import Foundation

enum RecommendationStyle: String, CaseIterable, Identifiable {
    case conservative
    case balanced
    case extended

    var id: String { rawValue }

    var title: String {
        switch self {
        case .conservative: return "Conservative"
        case .balanced: return "Balanced"
        case .extended: return "Extended"
        }
    }

    var intervalMultiplier: Double {
        switch self {
        case .conservative: return 0.8
        case .balanced: return 1.0
        case .extended: return 1.2
        }
    }

    var summary: String {
        switch self {
        case .conservative:
            return "Shorter intervals for extra safety margin."
        case .balanced:
            return "Default manufacturer/baseline intervals."
        case .extended:
            return "Longer intervals for lighter driving use."
        }
    }
}

enum RecommendationPreferences {
    private static let styleKey = "recommendation.style"

    static var style: RecommendationStyle {
        get {
            let raw = UserDefaults.standard.string(forKey: styleKey) ?? RecommendationStyle.balanced.rawValue
            return RecommendationStyle(rawValue: raw) ?? .balanced
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: styleKey)
        }
    }
}

enum RecommendationConfidence: String {
    case high = "High"
    case medium = "Medium"
    case baseline = "Baseline"

    var description: String {
        switch self {
        case .high:
            return "Uses VIN profile signals (engine/trim/year) to refine interval."
        case .medium:
            return "Uses VIN/make profile with limited per-service refinement."
        case .baseline:
            return "Uses default baseline guidance."
        }
    }
}

enum ManufacturerServiceRecommendations {
    @MainActor
    static func templates(for vehicle: Vehicle) -> [ServiceTemplate] {
        if let synced = ManufacturerScheduleSync.cachedTemplates(for: vehicle) {
            return applyRecommendationStyle(to: synced, style: RecommendationPreferences.style)
        }

        let profile = VehicleProfile(vehicle: vehicle)
        var templates = makeBaseline(for: profile)
        templates = applyVINRefinements(to: templates, profile: profile)
        templates = applyRecommendationStyle(to: templates, style: RecommendationPreferences.style)
        return templates
    }

    @MainActor
    static func sourceLabel(for vehicle: Vehicle) -> String {
        if ManufacturerScheduleSync.hasSyncedData(for: vehicle) {
            let style = RecommendationPreferences.style
            let suffix = style == .balanced ? "" : " • \(style.title)"
            return "Manufacturer Sync (\(ManufacturerScheduleSync.syncedSourceLabel(for: vehicle)))\(suffix)"
        }

        let profile = VehicleProfile(vehicle: vehicle)
        let base = makeSourceLabel(for: profile)

        guard profile.hasVIN else { return base }
        let style = RecommendationPreferences.style
        let suffix = style == .balanced ? "" : " • \(style.title)"
        if profile.hasEngineOrTrimSignals {
            return "VIN + \(base)\(suffix)"
        }
        return "VIN-Informed \(base)\(suffix)"
    }

    @MainActor
    static func template(for serviceName: String, vehicle: Vehicle) -> ServiceTemplate? {
        let normalized = normalize(serviceName)
        let options = serviceAliases(for: normalized)
        return templates(for: vehicle).first { options.contains(normalize($0.name)) }
    }

    @MainActor
    static func confidence(for serviceName: String, vehicle: Vehicle) -> RecommendationConfidence {
        let profile = VehicleProfile(vehicle: vehicle)
        guard profile.hasVIN else { return .baseline }

        let normalized = normalize(serviceName)
        let options = serviceAliases(for: normalized)
        let baselineTemplate = makeBaseline(for: profile).first { options.contains(normalize($0.name)) }
        let refinedTemplate = templates(for: vehicle).first { options.contains(normalize($0.name)) }

        guard let refinedTemplate else {
            return profile.hasEngineOrTrimSignals ? .medium : .baseline
        }

        if let baselineTemplate,
           profile.hasEngineOrTrimSignals,
           (baselineTemplate.intervalMiles != refinedTemplate.intervalMiles ||
            baselineTemplate.intervalMonths != refinedTemplate.intervalMonths) {
            return .high
        }

        return .medium
    }

    private static func makeBaseline(for profile: VehicleProfile) -> [ServiceTemplate] {
        let base = ServiceTemplates.all

        if profile.make.contains("tesla") || profile.model.contains("model ") || profile.isEV {
            return [
                ServiceTemplate(name: "Tire Rotation", intervalMiles: 6250, intervalMonths: 6, notes: "Common EV tire rotation interval."),
                ServiceTemplate(name: "Cabin Air Filter", intervalMiles: 0, intervalMonths: 24, notes: "Typical Tesla recommendation."),
                ServiceTemplate(name: "Brake Fluid", intervalMiles: 0, intervalMonths: 24, notes: "Brake fluid moisture check every 2 years."),
                ServiceTemplate(name: "HV Battery Coolant", intervalMiles: 0, intervalMonths: 48, notes: "Inspect/replace per model-specific service schedule.")
            ]
        }

        if profile.make.contains("toyota") || profile.make.contains("lexus") {
            return adjust(base) { template in
                switch template.name {
                case "Oil Change":
                    return ServiceTemplate(name: template.name, intervalMiles: 10000, intervalMonths: 12, notes: "Typical Toyota/Lexus schedule with synthetic oil; verify your owner's manual.")
                case "Transmission Fluid":
                    return ServiceTemplate(name: template.name, intervalMiles: 60000, intervalMonths: 72, notes: "Toyota/Lexus baseline for transmission service in mixed driving.")
                case "Coolant":
                    return ServiceTemplate(name: template.name, intervalMiles: 100000, intervalMonths: 120, notes: "Toyota long-life coolant often has longer first interval.")
                case "Brake Inspection":
                    return ServiceTemplate(name: template.name, intervalMiles: 10000, intervalMonths: 12, notes: "Inspect brake wear and hardware at regular service intervals.")
                case "Brake Pads/Rotors":
                    return ServiceTemplate(name: template.name, intervalMiles: 40000, intervalMonths: 48, notes: "Wear item interval depends on driving habits and terrain.")
                default:
                    return template
                }
            }
        }

        if profile.make.contains("honda") || profile.make.contains("acura") {
            return adjust(base) { template in
                switch template.name {
                case "Oil Change":
                    return ServiceTemplate(name: template.name, intervalMiles: 7500, intervalMonths: 12, notes: "Many Honda/Acura vehicles use Maintenance Minder; this is a general baseline.")
                case "Brake Fluid":
                    return ServiceTemplate(name: template.name, intervalMiles: 0, intervalMonths: 36, notes: "Honda often recommends brake fluid replacement every 3 years.")
                case "Transmission Fluid":
                    return ServiceTemplate(name: template.name, intervalMiles: 45000, intervalMonths: 48, notes: "Honda/Acura automatic/CVT fluid is commonly serviced earlier than generic intervals.")
                case "Brake Inspection":
                    return ServiceTemplate(name: template.name, intervalMiles: 10000, intervalMonths: 12, notes: "Frequent inspection aligns with Maintenance Minder service flow.")
                default:
                    return template
                }
            }
        }

        if profile.make.contains("ford") || profile.make.contains("lincoln") {
            return adjust(base) { template in
                switch template.name {
                case "Oil Change":
                    return ServiceTemplate(name: template.name, intervalMiles: 7500, intervalMonths: 12, notes: "General Ford/Lincoln baseline; check Intelligent Oil-Life Monitor.")
                case "Transmission Fluid":
                    return ServiceTemplate(name: template.name, intervalMiles: 60000, intervalMonths: 60, notes: "Ford/Lincoln severe-duty and towing usage may need shorter intervals.")
                case "Brake Inspection":
                    return ServiceTemplate(name: template.name, intervalMiles: 10000, intervalMonths: 12, notes: "Inspect brakes at least once a year or every tire rotation cycle.")
                default:
                    return template
                }
            }
        }

        if profile.make.contains("bmw") || profile.make.contains("mini") {
            return adjust(base) { template in
                switch template.name {
                case "Oil Change":
                    return ServiceTemplate(name: template.name, intervalMiles: 10000, intervalMonths: 12, notes: "Common BMW/MINI interval with synthetic oil.")
                case "Spark Plugs":
                    return ServiceTemplate(name: template.name, intervalMiles: 60000, intervalMonths: 48, notes: "Common BMW turbo engine interval; verify by engine code.")
                case "Brake Fluid":
                    return ServiceTemplate(name: template.name, intervalMiles: 0, intervalMonths: 24, notes: "BMW/MINI commonly call for brake fluid flush every 2 years.")
                case "Transmission Fluid":
                    return ServiceTemplate(name: template.name, intervalMiles: 60000, intervalMonths: 72, notes: "ZF and other transmissions often benefit from 60k-mile service despite lifetime-fill claims.")
                default:
                    return template
                }
            }
        }

        return base
    }

    private static func applyVINRefinements(to templates: [ServiceTemplate], profile: VehicleProfile) -> [ServiceTemplate] {
        adjust(templates) { template in
            var miles = template.intervalMiles
            var months = template.intervalMonths
            var notes = template.notes

            if profile.isTurbo && template.name == "Oil Change" {
                miles = minNonZero(miles, 5000)
                months = minNonZero(months, 6)
                notes = notes + " Turbo engine detected from VIN profile; interval tightened."
            }

            if profile.isDiesel && template.name == "Oil Change" {
                miles = minNonZero(miles, 7500)
                months = minNonZero(months, 12)
                notes = notes + " Diesel profile detected; severe-duty intervals may be shorter."
            }

            if profile.isHybrid && template.name == "Brake Fluid" {
                months = minNonZero(months, 36)
                notes = notes + " Hybrid profile: brake fluid check interval retained even with regenerative braking."
            }

            if profile.isPerformanceTrim {
                if template.name == "Oil Change" {
                    miles = minNonZero(miles, 5000)
                    months = minNonZero(months, 6)
                    notes = notes + " Performance trim detected; conservative interval applied."
                }
                if template.name == "Brake Fluid" {
                    months = minNonZero(months, 24)
                }
            }

            if profile.year > 0 && profile.year <= 2012 {
                if template.name == "Coolant" {
                    miles = minNonZero(miles, 50000)
                    months = minNonZero(months, 60)
                    notes = notes + " Older model year detected; conservative coolant interval applied."
                }
                if template.name == "Spark Plugs" {
                    miles = minNonZero(miles, 45000)
                    months = minNonZero(months, 48)
                }
            }

            if profile.isTruckOrTowingModel {
                if template.name == "Engine Air Filter" {
                    miles = minNonZero(miles, 12000)
                    months = minNonZero(months, 12)
                    notes = notes + " Truck/towing profile detected; shorter air-filter interval applied."
                }
                if template.name == "Inspection" {
                    miles = minNonZero(miles, 5000)
                    months = minNonZero(months, 6)
                }
            }

            return ServiceTemplate(
                name: template.name,
                intervalMiles: miles,
                intervalMonths: months,
                notes: notes
            )
        }
    }

    private static func makeSourceLabel(for profile: VehicleProfile) -> String {
        if profile.make.isEmpty { return "Generic Baseline" }
        if profile.make.contains("toyota") || profile.make.contains("lexus") { return "Toyota/Lexus Baseline" }
        if profile.make.contains("honda") || profile.make.contains("acura") { return "Honda/Acura Baseline" }
        if profile.make.contains("ford") || profile.make.contains("lincoln") { return "Ford/Lincoln Baseline" }
        if profile.make.contains("bmw") || profile.make.contains("mini") { return "BMW/MINI Baseline" }
        if profile.make.contains("tesla") { return "Tesla Baseline" }
        return "Generic Baseline"
    }

    private static func adjust(_ templates: [ServiceTemplate], _ transform: (ServiceTemplate) -> ServiceTemplate) -> [ServiceTemplate] {
        templates.map(transform)
    }

    private static func minNonZero(_ current: Double, _ candidate: Double) -> Double {
        if current <= 0 { return candidate }
        return min(current, candidate)
    }

    private static func minNonZero(_ current: Int, _ candidate: Int) -> Int {
        if current <= 0 { return candidate }
        return min(current, candidate)
    }

    private static func applyRecommendationStyle(to templates: [ServiceTemplate], style: RecommendationStyle) -> [ServiceTemplate] {
        guard style != .balanced else { return templates }
        return templates.map { template in
            let miles = scaleMiles(template.intervalMiles, style: style)
            let months = scaleMonths(template.intervalMonths, style: style)
            let noteSuffix = " Recommendation style: \(style.title)."
            let notes = template.notes.contains(noteSuffix) ? template.notes : template.notes + noteSuffix
            return ServiceTemplate(
                name: template.name,
                intervalMiles: miles,
                intervalMonths: months,
                notes: notes
            )
        }
    }

    private static func scaleMiles(_ miles: Double, style: RecommendationStyle) -> Double {
        guard miles > 0 else { return miles }
        let scaled = miles * style.intervalMultiplier
        let rounded = (scaled / 500).rounded() * 500
        return max(500, rounded)
    }

    private static func scaleMonths(_ months: Int, style: RecommendationStyle) -> Int {
        guard months > 0 else { return months }
        let scaled = (Double(months) * style.intervalMultiplier).rounded()
        return max(1, Int(scaled))
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func serviceAliases(for normalized: String) -> Set<String> {
        switch normalized {
        case "brake inspection", "brake pads rotors", "brake pads and rotors":
            return ["brake inspection", "brake pads rotors", "brake fluid", "inspection"]
        case "transmission fluid":
            return ["transmission fluid", "inspection"]
        case "power steering fluid":
            return ["power steering fluid", "inspection"]
        case "fuel system service":
            return ["fuel system service", "inspection"]
        case "belts and hoses":
            return ["belts and hoses", "inspection"]
        case "ac service":
            return ["ac service", "inspection"]
        case "alignment":
            return ["alignment", "tire rotation", "inspection"]
        case "tire replacement":
            return ["tire rotation"]
        case "detailing":
            return ["inspection"]
        default:
            return [normalized]
        }
    }
}

private struct VehicleProfile {
    let make: String
    let model: String
    let trim: String
    let engine: String
    let year: Int
    let hasVIN: Bool

    init(vehicle: Vehicle) {
        make = (vehicle.make ?? "").lowercased()
        model = (vehicle.model ?? "").lowercased()
        trim = (vehicle.trim ?? "").lowercased()
        engine = (vehicle.engine ?? "").lowercased()
        year = Int(vehicle.year)
        hasVIN = !(vehicle.vin ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasEngineOrTrimSignals: Bool {
        !trim.isEmpty || !engine.isEmpty || year > 0
    }

    var isEV: Bool {
        let text = "\(engine) \(trim) \(model)"
        return text.contains("electric")
            || text.contains("bev")
            || make.contains("tesla")
    }

    var isHybrid: Bool {
        let text = "\(engine) \(trim) \(model)"
        return text.contains("hybrid")
            || text.contains("phev")
            || text.contains("plug-in")
    }

    var isTurbo: Bool {
        let text = "\(engine) \(trim)"
        return text.contains("turbo")
            || text.contains("ecoboost")
            || text.contains("tsi")
            || text.contains("t-gdi")
    }

    var isDiesel: Bool {
        let text = "\(engine) \(trim)"
        return text.contains("diesel")
            || text.contains("tdi")
            || text.contains("duramax")
            || text.contains("power stroke")
            || text.contains("cummins")
    }

    var isPerformanceTrim: Bool {
        let text = "\(trim) \(model)"
        let flags = [
            "type r", "trd", "amg", "nismo", "sti", "srt",
            "m3", "m4", "m5", "m6", "x3m", "x4m", "x5m", "x6m",
            "rs3", "rs4", "rs5", "rs6", "rs7", "rsq8", "focus rs",
            "st-line", "gti", "gti autobahn", "golf r"
        ]
        return flags.contains(where: { text.contains($0) })
    }

    var isTruckOrTowingModel: Bool {
        let text = "\(model) \(trim)"
        return text.contains("f-150")
            || text.contains("f150")
            || text.contains("silverado")
            || text.contains("sierra")
            || text.contains("ram")
            || text.contains("tundra")
            || text.contains("tacoma")
            || text.contains("ranger")
            || text.contains("frontier")
    }
}
