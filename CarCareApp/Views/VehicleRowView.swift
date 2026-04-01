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
                        .fill(Color(.secondarySystemBackground))
                    Image(systemName: "car.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                .frame(width: 56, height: 56)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.displayName)
                    .font(.headline)
                Text(vehicleRowSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let statusLine {
                    Text(statusLine)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
            }
        }
    }

    private var vehicleRowSubtitle: String {
        let plateText = (vehicle.plate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let mileageText = vehicle.latestKnownMileage > 0 ? "\(Formatters.mileageLabel(vehicle.latestKnownMileage)) mi" : nil

        let parts = [plateText.isEmpty ? nil : plateText, mileageText].compactMap { $0 }
        return parts.isEmpty ? "No plate or mileage yet" : parts.joined(separator: " • ")
    }

    private var statusLine: String? {
        if vehicle.overdueReminderCount > 0 {
            return "\(vehicle.overdueReminderCount) reminder\(vehicle.overdueReminderCount == 1 ? "" : "s") overdue"
        }
        if vehicle.dueSoonReminderCount > 0 {
            return "\(vehicle.dueSoonReminderCount) reminder\(vehicle.dueSoonReminderCount == 1 ? "" : "s") due soon"
        }
        if vehicle.totalServiceCount > 0 {
            return "Last service \(vehicle.sortedLogs.first?.date.formatted(date: .abbreviated, time: .omitted) ?? "recently")"
        }
        return "Ready to log your first service"
    }

    private var statusColor: Color {
        if vehicle.overdueReminderCount > 0 {
            return .red
        }
        if vehicle.dueSoonReminderCount > 0 {
            return .orange
        }
        return .secondary
    }
}
