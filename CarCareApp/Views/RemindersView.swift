import SwiftUI
import CoreData

struct RemindersView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var vehicle: Vehicle

    @State private var showingAddReminder = false
    @State private var editingReminder: Reminder?
    @State private var reminderPendingDeletion: Reminder?

    var body: some View {
        List {
            if activeReminders.isEmpty {
                VStack(spacing: 16) {
                    EmptyStateView("No Reminders Yet", systemImage: "bell", message: "Set your first reminder so this app can tell you what needs attention next.")
                    Button("Add Reminder") {
                        showingAddReminder = true
                    }
                    .buttonStyle(.borderedProminent)
                    Text("Tip: reminders are easiest right after you save a service.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                if !urgentReminders.isEmpty {
                    Section {
                        ForEach(urgentReminders) { reminder in
                            reminderButton(reminder)
                        }
                    } header: {
                        Text("Needs Attention")
                    } footer: {
                        Text("Overdue and due-soon reminders stay at the top so you can act quickly.")
                    }
                }

                if !upcomingReminders.isEmpty {
                    Section {
                        ForEach(upcomingReminders) { reminder in
                            reminderButton(reminder)
                        }
                    } header: {
                        HStack {
                            Text("Coming Up")
                            Spacer()
                            Button("Add Reminder") {
                                showingAddReminder = true
                            }
                            .font(.subheadline)
                        }
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
                Text("Use these if you want a quick starting point for common maintenance.")
                    .font(.caption2)
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
        .alert("Delete Reminder?", isPresented: reminderDeleteAlertBinding) {
            Button("Cancel", role: .cancel) {
                reminderPendingDeletion = nil
            }
            Button("Delete", role: .destructive) {
                confirmDeleteReminder()
            }
        } message: {
            Text("This will remove \(reminderPendingDeletion?.title ?? "this reminder") and cancel its notification.")
        }
    }

    private var activeReminders: [Reminder] {
        vehicle.sortedReminders.filter { !$0.isCompleted }
    }

    private var urgentReminders: [Reminder] {
        activeReminders.filter {
            let urgency = vehicle.reminderUrgency(for: $0)
            return urgency == .overdue || urgency == .dueSoon
        }
    }

    private var upcomingReminders: [Reminder] {
        activeReminders.filter { vehicle.reminderUrgency(for: $0) == .upcoming }
    }

    private var completedReminders: [Reminder] {
        vehicle.sortedReminders.filter { $0.isCompleted }
    }

    private var recommendationTemplates: [ServiceTemplate] {
        ManufacturerServiceRecommendations.templates(for: vehicle)
    }

    private var reminderDeleteAlertBinding: Binding<Bool> {
        Binding(
            get: { reminderPendingDeletion != nil },
            set: { if !$0 { reminderPendingDeletion = nil } }
        )
    }

    private func confirmDeleteReminder() {
        guard let reminderPendingDeletion else { return }
        withAnimation {
            NotificationManager.shared.removeNotification(for: reminderPendingDeletion)
            viewContext.delete(reminderPendingDeletion)
            saveContext(savedMessage: "Reminder removed")
            self.reminderPendingDeletion = nil
        }
    }

    private func saveContext(savedMessage: String) {
        do {
            try viewContext.save()
            AppFeedbackCenter.shared.show(savedMessage)
        } catch {
            AppErrorCenter.shared.message = "Could not save your reminder changes right now."
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
    private func reminderButton(_ reminder: Reminder) -> some View {
        Button {
            editingReminder = reminder
        } label: {
            ReminderRowView(reminder: reminder, vehicle: vehicle, currentMileage: vehicle.currentMileage)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                reminderPendingDeletion = reminder
            }
            Button("Done") {
                reminder.isCompleted = true
                NotificationManager.shared.removeNotification(for: reminder)
                saveContext(savedMessage: "Reminder marked done")
            }
            .tint(.green)
        }
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
        let urgency = vehicle.reminderUrgency(for: reminder)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(reminder.title ?? "Reminder")
                    .font(.headline)
                urgencyBadge(urgency)
            }
            if let details = reminder.details, !details.isEmpty {
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if let dueDate = reminder.dueDate {
                    Text(dateLine(for: dueDate, urgency: urgency))
                }

                if reminder.dueMileage > 0 {
                    let remaining = reminder.dueMileage - currentMileage
                    let milesText = Formatters.mileageLabel(abs(remaining))
                    Text(mileageLine(for: remaining, milesText: milesText, urgency: urgency))
                }
            }
            .font(.caption)
            .foregroundStyle(urgency == .overdue ? .red : .secondary)

            if let linked = vehicle.log(with: reminder.linkedServiceLogID) {
                Text("Linked service: \(linked.title ?? "Service")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    private func urgencyBadge(_ urgency: ReminderUrgency) -> some View {
        Text(urgencyLabel(urgency))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(urgencyColor(urgency).opacity(0.14))
            .foregroundStyle(urgencyColor(urgency))
            .clipShape(Capsule())
    }

    private func urgencyLabel(_ urgency: ReminderUrgency) -> String {
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

    private func mileageLine(for remaining: Double, milesText: String, urgency: ReminderUrgency) -> String {
        switch urgency {
        case .overdue:
            return "Overdue by \(milesText) mi"
        case .dueSoon:
            return "Due soon: \(milesText) mi"
        case .upcoming, .completed:
            return "Due in \(Formatters.mileageLabel(max(remaining, 0))) mi"
        }
    }
}
