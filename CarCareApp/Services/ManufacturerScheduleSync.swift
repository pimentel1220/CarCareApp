import Foundation

struct ManufacturerScheduleSyncResult {
    let templates: [ServiceTemplate]
    let syncedAt: Date
    let source: SyncedScheduleSource
}

enum ProviderConnectionStatus {
    case connected(String)
    case authFailed(String)
    case invalidResponse(String)
    case failed(String)
}

enum SyncedScheduleSource: String, Codable {
    case genericREST = "Generic REST"
    case localBaseline = "Local Baseline"
    case autoGenericREST = "Auto -> Generic REST"
    case autoFallbackBaseline = "Auto -> Local Baseline Fallback"

    var label: String { rawValue }
}

enum ScheduleProviderType: String, CaseIterable, Identifiable {
    case auto
    case genericREST
    case localBaseline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Auto (Best Available)"
        case .genericREST: return "Generic REST Provider"
        case .localBaseline: return "Local Baseline"
        }
    }
}

enum ScheduleAuthMode: String, CaseIterable, Identifiable {
    case none
    case bearer
    case header
    case queryParam
    case carScanDualHeader

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .bearer: return "Bearer Token"
        case .header: return "Custom Header"
        case .queryParam: return "Query Parameter"
        case .carScanDualHeader: return "CarScan Dual Header"
        }
    }
}

struct ScheduleProviderSettings {
    var provider: ScheduleProviderType
    var endpointTemplate: String
    var authMode: ScheduleAuthMode
    var authToken: String
    var partnerToken: String
    var authHeaderName: String
    var authQueryKey: String

    static func load() -> ScheduleProviderSettings {
        let raw = UserDefaults.standard.string(forKey: Keys.provider) ?? ScheduleProviderType.auto.rawValue
        let authRaw = UserDefaults.standard.string(forKey: Keys.authMode) ?? ScheduleAuthMode.none.rawValue
        return ScheduleProviderSettings(
            provider: ScheduleProviderType(rawValue: raw) ?? .auto,
            endpointTemplate: UserDefaults.standard.string(forKey: Keys.endpointTemplate) ?? "",
            authMode: ScheduleAuthMode(rawValue: authRaw) ?? .none,
            authToken: UserDefaults.standard.string(forKey: Keys.authToken) ?? "",
            partnerToken: UserDefaults.standard.string(forKey: Keys.partnerToken) ?? "",
            authHeaderName: UserDefaults.standard.string(forKey: Keys.authHeaderName) ?? "X-API-Key",
            authQueryKey: UserDefaults.standard.string(forKey: Keys.authQueryKey) ?? "api_key"
        )
    }

    func save() {
        UserDefaults.standard.set(provider.rawValue, forKey: Keys.provider)
        UserDefaults.standard.set(endpointTemplate, forKey: Keys.endpointTemplate)
        UserDefaults.standard.set(authMode.rawValue, forKey: Keys.authMode)
        UserDefaults.standard.set(authToken, forKey: Keys.authToken)
        UserDefaults.standard.set(partnerToken, forKey: Keys.partnerToken)
        UserDefaults.standard.set(authHeaderName, forKey: Keys.authHeaderName)
        UserDefaults.standard.set(authQueryKey, forKey: Keys.authQueryKey)
    }

    mutating func applyCarMDPreset() {
        provider = .genericREST
        endpointTemplate = "https://api.carmd.com/v3.0/maintlist?vin={vin}"
        authMode = .carScanDualHeader
        if authHeaderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            authHeaderName = "X-API-Key"
        }
        if authQueryKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            authQueryKey = "api_key"
        }
    }

    private enum Keys {
        static let provider = "schedule.provider.type"
        static let endpointTemplate = "schedule.provider.endpointTemplate"
        static let authMode = "schedule.provider.authMode"
        static let authToken = "schedule.provider.authToken"
        static let partnerToken = "schedule.provider.partnerToken"
        static let authHeaderName = "schedule.provider.authHeaderName"
        static let authQueryKey = "schedule.provider.authQueryKey"
    }
}

enum ScheduleProviderError: LocalizedError {
    case missingEndpointTemplate
    case invalidEndpoint
    case unauthorized
    case forbidden
    case unexpectedStatus(Int)
    case emptyResponse
    case noSupportedItems

    var errorDescription: String? {
        switch self {
        case .missingEndpointTemplate:
            return "Set a provider endpoint first."
        case .invalidEndpoint:
            return "The provider endpoint is invalid."
        case .unauthorized:
            return "Authorization failed (401). Check credentials."
        case .forbidden:
            return "Access forbidden (403). Check account permissions."
        case .unexpectedStatus(let code):
            return "Provider returned HTTP \(code)."
        case .emptyResponse:
            return "Provider returned an empty schedule response."
        case .noSupportedItems:
            return "Provider response did not include supported service items."
        }
    }
}

enum ManufacturerScheduleSync {
    @MainActor
    static func sync(for vehicle: Vehicle) async throws -> ManufacturerScheduleSyncResult {
        let vin = VINDecoder.sanitize(vehicle.vin ?? "")
        guard vin.count >= 11 else {
            throw VINDecodeError.invalidVIN
        }

        let settings = ScheduleProviderSettings.load()
        let fetchResult = try await fetchTemplates(for: vehicle, settings: settings)
        let syncedAt = Date()
        save(templates: fetchResult.templates, source: fetchResult.source, for: vehicle, syncedAt: syncedAt)
        return ManufacturerScheduleSyncResult(templates: fetchResult.templates, syncedAt: syncedAt, source: fetchResult.source)
    }

    @MainActor
    static func cachedTemplates(for vehicle: Vehicle) -> [ServiceTemplate]? {
        guard let key = cacheKey(for: vehicle),
              let data = UserDefaults.standard.data(forKey: key),
              let payload = try? JSONDecoder().decode(ScheduleCachePayload.self, from: data)
        else {
            return nil
        }
        return payload.templates.map {
            ServiceTemplate(
                name: $0.name,
                intervalMiles: $0.intervalMiles,
                intervalMonths: $0.intervalMonths,
                notes: $0.notes
            )
        }
    }

    @MainActor
    static func lastSyncedAt(for vehicle: Vehicle) -> Date? {
        guard let key = cacheKey(for: vehicle),
              let data = UserDefaults.standard.data(forKey: key),
              let payload = try? JSONDecoder().decode(ScheduleCachePayload.self, from: data)
        else {
            return nil
        }
        return payload.syncedAt
    }

    @MainActor
    static func hasSyncedData(for vehicle: Vehicle) -> Bool {
        cachedTemplates(for: vehicle) != nil
    }

    @MainActor
    static func providerLabel() -> String {
        let settings = ScheduleProviderSettings.load()
        return settings.provider.title
    }

    @MainActor
    static func syncedSourceLabel(for vehicle: Vehicle) -> String {
        guard let key = cacheKey(for: vehicle),
              let data = UserDefaults.standard.data(forKey: key),
              let payload = try? JSONDecoder().decode(ScheduleCachePayload.self, from: data)
        else {
            return providerLabel()
        }
        return payload.source.label
    }

    @MainActor
    static func testConnection(for vehicle: Vehicle) async -> ProviderConnectionStatus {
        let vin = VINDecoder.sanitize(vehicle.vin ?? "")
        guard vin.count >= 11 else {
            return .failed("Add a valid VIN before testing.")
        }

        let settings = ScheduleProviderSettings.load()

        if settings.provider == .localBaseline {
            return .connected("Local baseline provider is available.")
        }

        do {
            let fetchResult = try await fetchTemplates(for: vehicle, settings: settings)
            let source = settings.provider == .auto ? "Auto provider route" : "Configured provider"
            if fetchResult.source == .autoFallbackBaseline {
                return .invalidResponse("Remote provider did not validate. Auto mode is currently using local baseline fallback.")
            }
            return .connected("\(source) returned \(fetchResult.templates.count) service templates (\(fetchResult.source.label)).")
        } catch let error as ScheduleProviderError {
            switch error {
            case .unauthorized, .forbidden:
                return .authFailed(error.localizedDescription)
            case .emptyResponse, .noSupportedItems:
                return .invalidResponse(error.localizedDescription)
            default:
                return .failed(error.localizedDescription)
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private static func fetchTemplates(for vehicle: Vehicle, settings: ScheduleProviderSettings) async throws -> FetchTemplatesResult {
        switch settings.provider {
        case .auto:
            do {
                let templates = try await fetchFromGenericREST(for: vehicle, settings: settings)
                return FetchTemplatesResult(templates: templates, source: .autoGenericREST)
            } catch {
                return FetchTemplatesResult(templates: localBaselineTemplates(for: vehicle), source: .autoFallbackBaseline)
            }
        case .genericREST:
            return FetchTemplatesResult(
                templates: try await fetchFromGenericREST(for: vehicle, settings: settings),
                source: .genericREST
            )
        case .localBaseline:
            return FetchTemplatesResult(templates: localBaselineTemplates(for: vehicle), source: .localBaseline)
        }
    }

    private static func fetchFromGenericREST(for vehicle: Vehicle, settings: ScheduleProviderSettings) async throws -> [ServiceTemplate] {
        let vin = VINDecoder.sanitize(vehicle.vin ?? "")
        let endpoint = settings.endpointTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !endpoint.isEmpty else { throw ScheduleProviderError.missingEndpointTemplate }

        let endpointString: String
        if endpoint.contains("{vin}") {
            endpointString = endpoint.replacingOccurrences(of: "{vin}", with: vin)
        } else {
            let separator = endpoint.contains("?") ? "&" : "?"
            endpointString = "\(endpoint)\(separator)vin=\(vin)"
        }

        var endpointComponents = URLComponents(string: endpointString)
        if settings.authMode == .queryParam {
            let key = settings.authQueryKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = settings.authToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty, !value.isEmpty {
                var items = endpointComponents?.queryItems ?? []
                items.append(URLQueryItem(name: key, value: value))
                endpointComponents?.queryItems = items
            }
        }

        guard let url = endpointComponents?.url else {
            throw ScheduleProviderError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let token = settings.authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty && settings.authMode == .bearer {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if !token.isEmpty && settings.authMode == .header {
            let headerName = settings.authHeaderName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !headerName.isEmpty {
                request.setValue(token, forHTTPHeaderField: headerName)
            }
        }
        if settings.authMode == .carScanDualHeader {
            let auth = settings.authToken.trimmingCharacters(in: .whitespacesAndNewlines)
            let partner = settings.partnerToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if !auth.isEmpty {
                request.setValue(auth, forHTTPHeaderField: "authorization")
            }
            if !partner.isEmpty {
                request.setValue(partner, forHTTPHeaderField: "partner-token")
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200...299:
                break
            case 401:
                throw ScheduleProviderError.unauthorized
            case 403:
                throw ScheduleProviderError.forbidden
            default:
                throw ScheduleProviderError.unexpectedStatus(http.statusCode)
            }
        }
        guard !data.isEmpty else { throw ScheduleProviderError.emptyResponse }

        let items = try decodeRemoteItems(data: data)
        let normalized = normalizeRemoteItems(items)
        guard !normalized.isEmpty else { throw ScheduleProviderError.noSupportedItems }
        return normalized
    }

    private static func decodeRemoteItems(data: Data) throws -> [RemoteTemplate] {
        let decoder = JSONDecoder()
        if let direct = try? decoder.decode([RemoteTemplate].self, from: data) {
            return direct
        }
        if let wrapped = try? decoder.decode(RemoteTemplateWrappedResponse.self, from: data) {
            return wrapped.templates
        }
        if let wrapped = try? decoder.decode(RemoteTemplateDataResponse.self, from: data) {
            return wrapped.data
        }
        throw ScheduleProviderError.emptyResponse
    }

    private static func normalizeRemoteItems(_ items: [RemoteTemplate]) -> [ServiceTemplate] {
        let supported = Set(ServiceTemplates.all.map { normalize($0.name) })
        var selected: [String: ServiceTemplate] = [:]

        for item in items {
            let rawName = (item.serviceName ?? item.name ?? item.desc ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawName.isEmpty else { continue }
            let name = canonicalName(from: rawName)
            let normalized = normalize(name)
            guard supported.contains(normalized) else { continue }

            let miles = max(0, item.intervalMiles ?? item.cycleMileage ?? item.dueMileage ?? 0)
            let months = max(0, item.intervalMonths ?? 0)
            let notes = (item.notes ?? "Provider schedule item")
            selected[normalized] = ServiceTemplate(name: name, intervalMiles: miles, intervalMonths: months, notes: notes)
        }

        return ServiceTemplates.all.map { template in
            let key = normalize(template.name)
            return selected[key] ?? template
        }
    }

    private static func canonicalName(from rawName: String) -> String {
        let normalized = normalize(rawName)
        if normalized.contains("oil") && normalized.contains("filter") { return "Oil Change" }
        if normalized.contains("tire") && normalized.contains("rotation") { return "Tire Rotation" }
        if normalized.contains("air filter") && normalized.contains("cabin") { return "Cabin Air Filter" }
        if normalized.contains("air filter") { return "Engine Air Filter" }
        if normalized.contains("brake fluid") { return "Brake Fluid" }
        if normalized.contains("brake") && normalized.contains("inspection") { return "Brake Inspection" }
        if normalized.contains("brake") && (normalized.contains("pads") || normalized.contains("rotor")) { return "Brake Pads/Rotors" }
        if normalized.contains("transmission") && normalized.contains("fluid") { return "Transmission Fluid" }
        if normalized.contains("coolant") { return "Coolant" }
        if normalized.contains("spark plug") { return "Spark Plugs" }
        if normalized.contains("battery") { return "Battery" }
        if normalized.contains("alignment") { return "Alignment" }
        if normalized.contains("fuel") && normalized.contains("service") { return "Fuel System Service" }
        if normalized.contains("belt") || normalized.contains("hose") { return "Belts & Hoses" }
        if normalized.contains("ac") || normalized.contains("air conditioning") { return "AC Service" }
        if normalized.contains("inspection") { return "Inspection" }
        return ServiceTemplates.all.first { normalize($0.name) == normalized }?.name ?? rawName
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func localBaselineTemplates(for vehicle: Vehicle) -> [ServiceTemplate] {
        let make = (vehicle.make ?? "").lowercased()
        let year = Int(vehicle.year)
        let base = ServiceTemplates.all

        if make.contains("toyota") || make.contains("lexus") {
            return base.map { template in
                switch template.name {
                case "Oil Change":
                    return ServiceTemplate(name: template.name, intervalMiles: 10000, intervalMonths: 12, notes: "Synced baseline for Toyota/Lexus.")
                case "Transmission Fluid":
                    return ServiceTemplate(name: template.name, intervalMiles: 60000, intervalMonths: 72, notes: "Synced baseline for Toyota/Lexus.")
                default:
                    return template
                }
            }
        }
        if make.contains("honda") || make.contains("acura") {
            return base.map { template in
                switch template.name {
                case "Oil Change":
                    return ServiceTemplate(name: template.name, intervalMiles: 7500, intervalMonths: 12, notes: "Synced baseline for Honda/Acura.")
                case "Transmission Fluid":
                    return ServiceTemplate(name: template.name, intervalMiles: 45000, intervalMonths: 48, notes: "Synced baseline for Honda/Acura.")
                default:
                    return template
                }
            }
        }
        if make.contains("ford") || make.contains("lincoln") {
            return base.map { template in
                switch template.name {
                case "Oil Change":
                    return ServiceTemplate(name: template.name, intervalMiles: 7500, intervalMonths: 12, notes: "Synced baseline for Ford/Lincoln.")
                case "Transmission Fluid":
                    return ServiceTemplate(name: template.name, intervalMiles: 60000, intervalMonths: 60, notes: "Synced baseline for Ford/Lincoln.")
                default:
                    return template
                }
            }
        }
        if year > 0 && year <= 2012 {
            return base.map { template in
                if template.name == "Coolant" {
                    return ServiceTemplate(name: template.name, intervalMiles: 50000, intervalMonths: 60, notes: "Synced conservative coolant interval for older model years.")
                }
                return template
            }
        }
        return base
    }

    @MainActor
    private static func save(templates: [ServiceTemplate], source: SyncedScheduleSource, for vehicle: Vehicle, syncedAt: Date) {
        guard let key = cacheKey(for: vehicle) else { return }
        let payload = ScheduleCachePayload(
            syncedAt: syncedAt,
            source: source,
            templates: templates.map {
                SyncedTemplate(
                    name: $0.name,
                    intervalMiles: $0.intervalMiles,
                    intervalMonths: $0.intervalMonths,
                    notes: $0.notes
                )
            }
        )
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    @MainActor
    private static func cacheKey(for vehicle: Vehicle) -> String? {
        let vin = VINDecoder.sanitize(vehicle.vin ?? "")
        guard !vin.isEmpty else { return nil }
        return "manufacturer.schedule.\(vin)"
    }
}

private struct ScheduleCachePayload: Codable {
    let syncedAt: Date
    let source: SyncedScheduleSource
    let templates: [SyncedTemplate]

    init(syncedAt: Date, source: SyncedScheduleSource, templates: [SyncedTemplate]) {
        self.syncedAt = syncedAt
        self.source = source
        self.templates = templates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        syncedAt = try container.decode(Date.self, forKey: .syncedAt)
        source = try container.decodeIfPresent(SyncedScheduleSource.self, forKey: .source) ?? .localBaseline
        templates = try container.decode([SyncedTemplate].self, forKey: .templates)
    }
}

private struct SyncedTemplate: Codable {
    let name: String
    let intervalMiles: Double
    let intervalMonths: Int
    let notes: String
}

private struct RemoteTemplateWrappedResponse: Decodable {
    let templates: [RemoteTemplate]
}

private struct RemoteTemplateDataResponse: Decodable {
    let data: [RemoteTemplate]
}

private struct RemoteTemplate: Decodable {
    let serviceName: String?
    let name: String?
    let desc: String?
    let intervalMiles: Double?
    let cycleMileage: Double?
    let dueMileage: Double?
    let intervalMonths: Int?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case serviceName
        case name
        case desc
        case intervalMiles
        case cycleMileage = "cycle_mileage"
        case dueMileage = "due_mileage"
        case intervalMonths
        case notes
    }
}

private struct FetchTemplatesResult {
    let templates: [ServiceTemplate]
    let source: SyncedScheduleSource
}
