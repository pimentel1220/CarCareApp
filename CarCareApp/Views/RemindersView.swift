import SwiftUI
import CoreData

struct RemindersView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var vehicle: Vehicle

    @State private var showingAddReminder = false
    @State private var editingReminder: Reminder?

    var body: some View {
        List {
            if activeReminders.isEmpty {
                VStack(spacing: 16) {
                    EmptyStateView("No Reminders", systemImage: "bell", message: "Add a reminder to track upcoming service.")
                    Button("Add Reminder") {
                        showingAddReminder = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Section {
                    ForEach(activeReminders) { reminder in
                        Button {
                            editingReminder = reminder
                        } label: {
                            ReminderRowView(reminder: reminder, vehicle: vehicle, currentMileage: vehicle.currentMileage)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button("Done") {
                                reminder.isCompleted = true
                                NotificationManager.shared.removeNotification(for: reminder)
                                saveContext(savedMessage: "Reminder completed")
                            }
                            .tint(.green)
                        }
                    }
                    .onDelete(perform: deleteReminders)
                } header: {
                    HStack {
                        Text("Active")
                        Spacer()
                        Button("Add Reminder") {
                            showingAddReminder = true
                        }
                        .font(.subheadline)
                    }
                }
            }

            if !completedReminders.isEmpty {
                Section("Completed") {
                    ForEach(completedReminders) { reminder in
                        Button {
                            editingReminder = reminder
                        } label: {
                            ReminderRowView(reminder: reminder, vehicle: vehicle, currentMileage: vehicle.currentMileage)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("Suggested Services") {
                Text("Source: \(ManufacturerServiceRecommendations.sourceLabel(for: vehicle))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(recommendationTemplates) { template in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(template.name)
                                .font(.headline)
                            confidenceBadge(for: template)
                        }
                        Text(template.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(ManufacturerServiceRecommendations.confidence(for: template.name, vehicle: vehicle).description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Button("Add Reminder") {
                            addTemplateReminder(template)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Reminders")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddReminder = true
                } label: {
                    Label("Add Reminder", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddReminder) {
            ReminderFormView(vehicle: vehicle)
        }
        .sheet(item: $editingReminder) { reminder in
            ReminderFormView(vehicle: vehicle, existingReminder: reminder)
        }
    }

    private var activeReminders: [Reminder] {
        vehicle.sortedReminders.filter { !$0.isCompleted }
    }

    private var completedReminders: [Reminder] {
        vehicle.sortedReminders.filter { $0.isCompleted }
    }

    private var recommendationTemplates: [ServiceTemplate] {
        ManufacturerServiceRecommendations.templates(for: vehicle)
    }

    private func deleteReminders(offsets: IndexSet) {
        withAnimation {
            offsets.map { activeReminders[$0] }.forEach { reminder in
                NotificationManager.shared.removeNotification(for: reminder)
                viewContext.delete(reminder)
            }
            saveContext(savedMessage: "Reminder deleted")
        }
    }

    private func saveContext(savedMessage: String) {
        do {
            try viewContext.save()
            AppFeedbackCenter.shared.show(savedMessage)
        } catch {
            AppErrorCenter.shared.message = error.localizedDescription
        }
    }

    private func addTemplateReminder(_ template: ServiceTemplate) {
        let reminder = Reminder(context: viewContext)
        reminder.id = UUID()
        reminder.title = template.name
        reminder.details = template.notes
        reminder.lastServiceDate = Date()
        reminder.lastServiceMileage = vehicle.currentMileage
        reminder.repeatIntervalMonths = Int16(template.intervalMonths)
        reminder.repeatIntervalMiles = template.intervalMiles
        reminder.isCompleted = false
        reminder.vehicle = vehicle
        reminder.linkedServiceLogID = vehicle.sortedLogs.first?.id
        reminder.dueDate = Calendar.current.date(byAdding: .month, value: template.intervalMonths, to: Date())
        if vehicle.currentMileage > 0 && template.intervalMiles > 0 {
            reminder.dueMileage = vehicle.currentMileage + template.intervalMiles
        }

        NotificationManager.shared.scheduleNotification(for: reminder, vehicleName: vehicle.displayName)
        saveContext(savedMessage: "Reminder added")
    }

    @ViewBuilder
    private func confidenceBadge(for template: ServiceTemplate) -> some View {
        let confidence = ManufacturerServiceRecommendations.confidence(for: template.name, vehicle: vehicle)
        Text("Confidence: \(confidence.rawValue)")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(confidenceColor(confidence).opacity(0.15))
            .foregroundStyle(confidenceColor(confidence))
            .clipShape(Capsule())
    }

    private func confidenceColor(_ confidence: RecommendationConfidence) -> Color {
        switch confidence {
        case .high:
            return .green
        case .medium:
            return .orange
        case .baseline:
            return .secondary
        }
    }
}

private struct ReminderRowView: View {
    let reminder: Reminder
    let vehicle: Vehicle
    let currentMileage: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(reminder.title ?? "Reminder")
                .font(.headline)
            if let details = reminder.details, !details.isEmpty {
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if let dueDate = reminder.dueDate {
                    Text("Due \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                }

                if reminder.dueMileage > 0 {
                    let remaining = reminder.dueMileage - currentMileage
                    let milesText = Formatters.mileageLabel(abs(remaining))
                    Text(remaining <= 0 ? "Overdue by \(milesText) mi" : "Due in \(milesText) mi")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let linked = vehicle.log(with: reminder.linkedServiceLogID) {
                Text("Linked service: \(linked.title ?? "Service")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}
