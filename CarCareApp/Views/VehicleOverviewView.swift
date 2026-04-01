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
                                Text("VIN added for quicker vehicle details")
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
                    Label("Log Service", systemImage: "plus.circle")
                }

                Button {
                    onOpenParts()
                } label: {
                    Label("Track Part Replacement", systemImage: "gear.badge")
                }

                Button {
                    onOpenReminders()
                } label: {
                    Label("Set Reminder", systemImage: "bell.badge.fill")
                }

                Button {
                    onOpenInfo()
                } label: {
                    Label("View Vehicle Details", systemImage: "square.and.pencil")
                }
            }

            Section("What Needs Attention") {
                if vehicle.upcomingReminders.isEmpty {
                    Button {
                        onOpenReminders()
                    } label: {
                        emptyActionRow(
                            title: "No reminders yet",
                            message: "Set one now so this screen can tell you what is coming up.",
                            systemImage: "calendar.badge.exclamationmark"
                        )
                    }
                    .buttonStyle(.plain)
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
                    Button {
                        onOpenMaintenance()
                    } label: {
                        emptyActionRow(
                            title: "No service history yet",
                            message: "Log your first service so you can build a reliable maintenance record.",
                            systemImage: "wrench"
                        )
                    }
                    .buttonStyle(.plain)
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
                    Button {
                        onOpenParts()
                    } label: {
                        emptyActionRow(
                            title: "No part replacements yet",
                            message: "Track parts here when you swap filters, brakes, batteries, and more.",
                            systemImage: "gearshape"
                        )
                    }
                    .buttonStyle(.plain)
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
            vehicle.reminderUrgency(for: reminder) == .overdue
        }.count
        let dueSoonCount = vehicle.upcomingReminders.filter { vehicle.reminderUrgency(for: $0) == .dueSoon }.count

        let recentActivity = vehicle.sortedLogs.first?.date ?? vehicle.sortedParts.first?.date

        VStack(alignment: .leading, spacing: 6) {
            if overdueCount > 0 {
                Label("\(overdueCount) overdue reminder\(overdueCount == 1 ? "" : "s") need attention", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            } else if dueSoonCount > 0 {
                Label("\(dueSoonCount) reminder\(dueSoonCount == 1 ? "" : "s") due soon", systemImage: "clock.badge.exclamationmark.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)
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
    private func emptyActionRow(title: String, message: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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
        let urgency = reminder.vehicle?.reminderUrgency(for: reminder) ?? .upcoming
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(reminder.title ?? "Reminder")
                        .font(.headline)
                    urgencyBadge(urgency)
                }

                HStack(spacing: 10) {
                    if let dueDate = reminder.dueDate {
                        Text(dateLine(for: dueDate, urgency: urgency))
                    }

                    if reminder.dueMileage > 0 {
                        let remaining = reminder.dueMileage - currentMileage
                        Text(mileageLine(for: remaining, urgency: urgency))
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

    private func urgencyBadge(_ urgency: ReminderUrgency) -> some View {
        Text(urgencyTitle(urgency))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(urgencyColor(urgency).opacity(0.14))
            .foregroundStyle(urgencyColor(urgency))
            .clipShape(Capsule())
    }

    private func urgencyTitle(_ urgency: ReminderUrgency) -> String {
        switch urgency {
        case .overdue: return "Overdue"
        case .dueSoon: return "Due Soon"
        case .upcoming: return "Upcoming"
        case .completed: return "Done"
        }
    }

    private func urgencyColor(_ urgency: ReminderUrgency) -> Color {
        switch urgency {
        case .overdue: return .red
        case .dueSoon: return .orange
        case .upcoming: return .blue
        case .completed: return .secondary
        }
    }

    private func dateLine(for dueDate: Date, urgency: ReminderUrgency) -> String {
        switch urgency {
        case .overdue:
            return "Overdue since \(dueDate.formatted(date: .abbreviated, time: .omitted))"
        case .dueSoon:
            return "Due soon: \(dueDate.formatted(date: .abbreviated, time: .omitted))"
        case .upcoming, .completed:
            return "Due \(dueDate.formatted(date: .abbreviated, time: .omitted))"
        }
    }

    private func mileageLine(for remaining: Double, urgency: ReminderUrgency) -> String {
        let milesText = Formatters.mileageLabel(abs(remaining))
        switch urgency {
        case .overdue:
            return "Over by \(milesText) mi"
        case .dueSoon:
            return "Due soon: \(milesText) mi"
        case .upcoming, .completed:
            return "In \(Formatters.mileageLabel(max(remaining, 0))) mi"
        }
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
