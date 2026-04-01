import Foundation

struct DecodedVehicleInfo {
    let make: String?
    let model: String?
    let year: Int?
    let trim: String?
    let engine: String?
}

enum VINDecodeError: LocalizedError {
    case invalidVIN
    case noResults
    case serviceError(String)

    var errorDescription: String? {
        switch self {
        case .invalidVIN:
            return "Enter a valid VIN before decoding."
        case .noResults:
            return "No VIN results were returned."
        case .serviceError(let message):
            return message
        }
    }
}

enum VINDecoder {
    static func decode(vin rawVIN: String) async throws -> DecodedVehicleInfo {
        let cleanedVIN = sanitize(rawVIN)
        guard cleanedVIN.count >= 11 else {
            throw VINDecodeError.invalidVIN
        }

        let endpoint = "https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVinValuesExtended/\(cleanedVIN)?format=json"
        guard let url = URL(string: endpoint) else {
            throw VINDecodeError.serviceError("Unable to build VIN request URL.")
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(VINDecodeResponse.self, from: data)
        guard let item = response.results.first else {
            throw VINDecodeError.noResults
        }

        if let errorCode = item.errorCode?.trimmingCharacters(in: .whitespacesAndNewlines),
           errorCode != "0",
           let text = item.errorText,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw VINDecodeError.serviceError(text)
        }

        let enginePieces = [
            item.engineModel,
            item.engineCylinders.map { "\($0)-cyl" },
            item.displacementL.map { "\($0)L" },
            item.fuelTypePrimary
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let engine = enginePieces.isEmpty ? nil : enginePieces.joined(separator: " ")
        let trim = firstNonEmpty(item.trim, item.trim2, item.bodyClass)
        let year = Int(item.modelYear ?? "")

        return DecodedVehicleInfo(
            make: firstNonEmpty(item.make),
            model: firstNonEmpty(item.model),
            year: year,
            trim: trim,
            engine: engine
        )
    }

    static func sanitize(_ vin: String) -> String {
        vin
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }
}

private struct VINDecodeResponse: Decodable {
    let results: [VINDecodeItem]

    enum CodingKeys: String, CodingKey {
        case results = "Results"
    }
}

private struct VINDecodeItem: Decodable {
    let make: String?
    let model: String?
    let modelYear: String?
    let trim: String?
    let trim2: String?
    let bodyClass: String?
    let engineModel: String?
    let engineCylinders: String?
    let displacementL: String?
    let fuelTypePrimary: String?
    let errorCode: String?
    let errorText: String?

    enum CodingKeys: String, CodingKey {
        case make = "Make"
        case model = "Model"
        case modelYear = "ModelYear"
        case trim = "Trim"
        case trim2 = "Trim2"
        case bodyClass = "BodyClass"
        case engineModel = "EngineModel"
        case engineCylinders = "EngineCylinders"
        case displacementL = "DisplacementL"
        case fuelTypePrimary = "FuelTypePrimary"
        case errorCode = "ErrorCode"
        case errorText = "ErrorText"
    }
}
