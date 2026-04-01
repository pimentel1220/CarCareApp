import SwiftUI

struct VehicleOverviewView: View {
    @ObservedObject var vehicle: Vehicle
    var onOpenInfo: () -> Void
    var onOpenMaintenance: () -> Void
    var onOpenReminders: () -> Void
    var onOpenParts: () -> Void
    var onOpenService: (ServiceLog) -> Void
    var onOpenReminder: (Reminder) -> Void
    var onOpenPart: (PartReplacement) -> Void

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 14) {
                        vehicleImage

                        VStack(alignment: .leading, spacing: 6) {
                            Text(vehicle.displayName)
                                .font(.title3.weight(.semibold))

                            Text(vehicleOverviewLine)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let vin = vehicle.vin, !vin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("VIN ready for schedule sync")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    statusStrip

                    LazyVGrid(columns: overviewColumns, spacing: 12) {
                        OverviewMetricCard(
                            title: "Current Mileage",
                            value: vehicle.latestKnownMileage > 0 ? "\(Formatters.mileageLabel(vehicle.latestKnownMileage)) mi" : "Not set",
                            systemImage: "gauge.medium"
                        ) {
                            onOpenInfo()
                        }
                        OverviewMetricCard(
                            title: "Active Reminders",
                            value: "\(vehicle.activeReminders.count)",
                            systemImage: "bell.badge"
                        ) {
                            onOpenReminders()
                        }
                        OverviewMetricCard(
                            title: "Service Logs",
                            value: "\(vehicle.totalServiceCount)",
                            systemImage: "wrench.and.screwdriver"
                        ) {
                            onOpenMaintenance()
                        }
                        OverviewMetricCard(
                            title: "Total Spend",
                            value: vehicle.totalServiceSpend > 0 ? "$\(String(format: "%.2f", vehicle.totalServiceSpend))" : "Not tracked",
                            systemImage: "dollarsign.circle"
                        ) {
                            onOpenMaintenance()
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Quick Actions") {
                Button {
                    onOpenMaintenance()
                } label: {
                    Label("Add Service Log", systemImage: "plus.circle")
                }

                Button {
                    onOpenParts()
                } label: {
                    Label("Add Part Replacement", systemImage: "gear.badge")
                }

                Button {
                    onOpenReminders()
                } label: {
                    Label("Add Reminder", systemImage: "bell.badge.fill")
                }

                Button {
                    onOpenInfo()
                } label: {
                    Label("Edit Vehicle Info", systemImage: "square.and.pencil")
                }
            }

            Section("Upcoming Services") {
                if vehicle.upcomingReminders.isEmpty {
                    emptyRow("No active reminders yet", systemImage: "calendar.badge.exclamationmark")
                } else {
                    ForEach(vehicle.upcomingReminders.prefix(3)) { reminder in
                        Button {
                            onOpenReminder(reminder)
                        } label: {
                            OverviewReminderRow(reminder: reminder, currentMileage: vehicle.latestKnownMileage)
                        }
                        .buttonStyle(.plain)
                    }

                    if vehicle.upcomingReminders.count > 3 {
                        Button("See All Reminders") {
                            onOpenReminders()
                        }
                    }
                }
            }

            Section("Recent Maintenance") {
                if vehicle.recentLogs.isEmpty {
                    emptyRow("No maintenance history yet", systemImage: "wrench")
                } else {
                    ForEach(vehicle.recentLogs.prefix(3)) { log in
                        Button {
                            onOpenService(log)
                        } label: {
                            OverviewServiceRow(log: log)
                        }
                        .buttonStyle(.plain)
                    }

                    if vehicle.sortedLogs.count > 3 {
                        Button("See Full Maintenance History") {
                            onOpenMaintenance()
                        }
                    }
                }
            }

            Section("Recent Part Replacements") {
                if vehicle.recentParts.isEmpty {
                    emptyRow("No part replacements yet", systemImage: "gearshape")
                } else {
                    ForEach(vehicle.recentParts.prefix(3)) { part in
                        Button {
                            onOpenPart(part)
                        } label: {
                            OverviewPartRow(part: part, vehicle: vehicle)
                        }
                        .buttonStyle(.plain)
                    }

                    if vehicle.sortedParts.count > 3 {
                        Button("See All Parts") {
                            onOpenParts()
                        }
                    }
                }
            }
        }
        .navigationTitle("Overview")
    }

    private var overviewColumns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var vehicleOverviewLine: String {
        let plateText = (vehicle.plate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = [
            vehicle.year > 0 ? String(vehicle.year) : nil,
            vehicle.make,
            vehicle.model,
            plateText.isEmpty ? nil : plateText
        ]
        .compactMap { value -> String? in
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return summary.isEmpty ? "Start by adding your vehicle info." : summary.joined(separator: " • ")
    }

    @ViewBuilder
    private var statusStrip: some View {
        let overdueCount = vehicle.upcomingReminders.filter { reminder in
            (reminder.dueDate.map { $0 <= Date() } ?? false) ||
            (reminder.dueMileage > 0 && reminder.dueMileage <= vehicle.latestKnownMileage)
        }.count

        let recentActivity = vehicle.sortedLogs.first?.date ?? vehicle.sortedParts.first?.date

        VStack(alignment: .leading, spacing: 6) {
            if overdueCount > 0 {
                Label("\(overdueCount) overdue reminder\(overdueCount == 1 ? "" : "s") need attention", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            } else {
                Label("No overdue reminders right now", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }

            Text(recentActivity.map { "Last activity \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "No service history yet")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var vehicleImage: some View {
        if let data = vehicle.photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))
        } else {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.blue.opacity(0.14))
                .overlay {
                    Image(systemName: "car.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .frame(width: 80, height: 80)
        }
    }

    @ViewBuilder
    private func emptyRow(_ message: String, systemImage: String) -> some View {
        Label(message, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

private struct OverviewMetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.09))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct OverviewReminderRow: View {
    let reminder: Reminder
    let currentMileage: Double

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(reminder.title ?? "Reminder")
                    .font(.headline)

                HStack(spacing: 10) {
                    if let dueDate = reminder.dueDate {
                        Text(dueDate <= Date() ? "Overdue since \(dueDate.formatted(date: .abbreviated, time: .omitted))" : "Due \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                    }

                    if reminder.dueMileage > 0 {
                        let remaining = reminder.dueMileage - currentMileage
                        Text(remaining <= 0 ? "Over by \(Formatters.mileageLabel(abs(remaining))) mi" : "In \(Formatters.mileageLabel(remaining)) mi")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

private struct OverviewServiceRow: View {
    let log: ServiceLog

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(log.title ?? "Service")
                    .font(.headline)
                HStack(spacing: 10) {
                    Text(log.date.formatted(date: .abbreviated, time: .omitted))
                    if log.mileage > 0 {
                        Text("\(Formatters.mileageLabel(log.mileage)) mi")
                    }
                    if log.cost > 0 {
                        Text("$\(String(format: "%.2f", log.cost))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

private struct OverviewPartRow: View {
    let part: PartReplacement
    let vehicle: Vehicle

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(part.partName ?? "Part")
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Text(part.date.formatted(date: .abbreviated, time: .omitted))
                    if part.mileage > 0 {
                        Text("\(Formatters.mileageLabel(part.mileage)) mi")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let linked = vehicle.log(with: part.linkedServiceLogID) {
                    Text("Linked to \(linked.title ?? "Service")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
