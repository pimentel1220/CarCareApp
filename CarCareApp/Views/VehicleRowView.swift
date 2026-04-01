import SwiftUI

struct VehicleRowView: View {
    let vehicle: Vehicle

    var body: some View {
        HStack(spacing: 12) {
            if let data = vehicle.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.15))
                    Image(systemName: "car.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .frame(width: 56, height: 56)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.displayName)
                    .font(.headline)
                Text(vehicleRowSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var vehicleRowSubtitle: String {
        let plateText = (vehicle.plate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let mileageText = vehicle.latestKnownMileage > 0 ? "\(Formatters.mileageLabel(vehicle.latestKnownMileage)) mi" : nil

        let parts = [plateText.isEmpty ? nil : plateText, mileageText].compactMap { $0 }
        return parts.isEmpty ? "No plate or mileage yet" : parts.joined(separator: " • ")
    }
}
