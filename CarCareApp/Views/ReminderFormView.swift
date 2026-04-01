import SwiftUI
import CoreData

struct ReminderFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var vehicle: Vehicle
    var existingReminder: Reminder?

    @State private var title = ""
    @State private var details = ""
    @State private var lastServiceDate = Date()
    @State private var lastServiceMileage = ""
    @State private var intervalMonths = ""
    @State private var intervalMiles = ""
    @State private var linkedServiceLogID: UUID?
    @State private var originalMileage: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder") {
                    TextField("Title", text: $title, axis: .vertical)
                        .lineLimit(1...4)
                    TextField("Details", text: $details, axis: .vertical)
                        .lineLimit(1...5)
                }

                Section("Last Service") {
                    DatePicker("Date", selection: $lastServiceDate, displayedComponents: .date)
                    TextField("Mileage", text: $lastServiceMileage)
                        .keyboardType(.numbersAndPunctuation)

                    HStack {
                        Button("Use Current Mileage") {
                            lastServiceMileage = Formatters.mileageText(vehicle.latestKnownMileage)
                        }
                        .disabled(vehicle.latestKnownMileage <= 0)

                        Spacer()

                        Button("Use Linked Service") {
                            applyLinkedServiceDetails()
                        }
                        .disabled(vehicle.log(with: linkedServiceLogID) == nil)
                    }
                    .font(.caption)
                }

                Section("Interval") {
                    TextField("Months", text: $intervalMonths)
                        .keyboardType(.numberPad)
                    TextField("Miles", text: $intervalMiles)
                        .keyboardType(.numbersAndPunctuation)

                    Button("Use Recommended Interval") {
                        applyRecommendedInterval()
                    }
                }

                Section("Linked Service") {
                    if vehicle.sortedLogs.isEmpty {
                        Text("No service logs available to link yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Service", selection: $linkedServiceLogID) {
                            Text("None").tag(Optional<UUID>.none)
                            ForEach(vehicle.sortedLogs) { log in
                                Text(serviceLabel(for: log)).tag(Optional(log.id))
                            }
                        }
                        .pickerStyle(.menu)

                        Button("Use Linked Service Details") {
                            applyLinkedServiceDetails()
                        }
                    }
                }

                Section("Next Due") {
                    if let dueDate {
                        Text("Date: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                    } else {
                        Text("Date: Not set")
                    }

                    if let dueMileage {
                        Text("Mileage: \(Formatters.mileageLabel(dueMileage))")
                    } else {
                        Text("Mileage: Not set")
                    }

                    if dueDate == nil && dueMileage != nil {
                        Text("Mileage-only reminders are tracked in the app, but iPhone alerts need a due date.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(existingReminder == nil ? "Add Reminder" : "Edit Reminder")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if saveReminder() {
                            dismiss()
                        }
                    }
                }
            }
            .onAppear(perform: loadExistingReminder)
            .onChange(of: linkedServiceLogID) { _ in
                guard existingReminder == nil else { return }
                applyLinkedServiceDetailsIfNeeded()
            }
        }
    }

    private var dueDate: Date? {
        let months = Int(intervalMonths) ?? 0
        guard months > 0 else { return nil }
        return Calendar.current.date(byAdding: .month, value: months, to: lastServiceDate)
    }

    private var dueMileage: Double? {
        let miles = Formatters.parseMileage(intervalMiles) ?? 0
        guard miles > 0 else { return nil }
        let lastMiles = Formatters.parseMileage(lastServiceMileage) ?? 0
        return lastMiles + miles
    }

    private func loadExistingReminder() {
        if let existingReminder {
            title = existingReminder.title ?? ""
            details = existingReminder.details ?? ""
            lastServiceDate = existingReminder.lastServiceDate ?? Date()
            if existingReminder.lastServiceMileage > 0 {
                lastServiceMileage = Formatters.mileageText(existingReminder.lastServiceMileage)
            }
            if existingReminder.repeatIntervalMonths > 0 {
                intervalMonths = String(existingReminder.repeatIntervalMonths)
            }
            if existingReminder.repeatIntervalMiles > 0 {
                intervalMiles = Formatters.mileageText(existingReminder.repeatIntervalMiles)
            }
            linkedServiceLogID = existingReminder.linkedServiceLogID
            originalMileage = existingReminder.lastServiceMileage
        } else if vehicle.latestKnownMileage > 0 {
            lastServiceMileage = Formatters.mileageText(vehicle.latestKnownMileage)
            linkedServiceLogID = vehicle.sortedLogs.first?.id
            applyLinkedServiceDetailsIfNeeded()
        }
    }

    @discardableResult
    private func saveReminder() -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            AppErrorCenter.shared.message = "Title is required."
            return false
        }

        let months = Int16(intervalMonths) ?? 0
        let miles = Formatters.parseMileage(intervalMiles) ?? 0
        guard months > 0 || miles > 0 else {
            AppErrorCenter.shared.message = "Enter a month or mileage interval."
            return false
        }

        let serviceMileage = Formatters.parseMileage(lastServiceMileage) ?? 0
        guard serviceMileage >= 0 else {
            AppErrorCenter.shared.message = "Mileage cannot be negative."
            return false
        }
        if existingReminder != nil, serviceMileage > 0, serviceMileage < originalMileage {
            AppErrorCenter.shared.message = "Reminder mileage cannot be lower than the previous value."
            return false
        }
        if existingReminder == nil, serviceMileage > 0, serviceMileage < vehicle.latestKnownMileage {
            AppErrorCenter.shared.message = "Reminder mileage cannot be lower than the current vehicle mileage."
            return false
        }

        let reminder = existingReminder ?? Reminder(context: viewContext)
        if existingReminder == nil {
            reminder.id = UUID()
            reminder.vehicle = vehicle
            reminder.isCompleted = false
        }

        reminder.title = trimmedTitle
        reminder.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
        reminder.lastServiceDate = lastServiceDate
        reminder.lastServiceMileage = serviceMileage
        reminder.repeatIntervalMonths = months
        reminder.repeatIntervalMiles = miles
        reminder.dueDate = dueDate
        reminder.dueMileage = dueMileage ?? 0
        reminder.linkedServiceLogID = linkedServiceLogID

        if reminder.dueDate != nil {
            NotificationManager.shared.scheduleNotification(for: reminder, vehicleName: vehicle.displayName)
        } else {
            NotificationManager.shared.removeNotification(for: reminder)
        }

        do {
            try viewContext.save()
            AppFeedbackCenter.shared.show("Reminder saved")
            return true
        } catch {
            AppErrorCenter.shared.message = error.localizedDescription
            return false
        }
    }

    private func serviceLabel(for log: ServiceLog) -> String {
        let name = (log.title ?? "Service").trimmingCharacters(in: .whitespacesAndNewlines)
        let date = log.date.formatted(date: .abbreviated, time: .omitted)
        return "\(name) - \(date)"
    }

    private func applyLinkedServiceDetailsIfNeeded() {
        guard title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }
        applyLinkedServiceDetails()
    }

    private func applyLinkedServiceDetails() {
        guard let linkedService = vehicle.log(with: linkedServiceLogID) else { return }

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            title = "\(linkedService.title ?? "Service") Reminder"
        }

        if details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            details = "Reminder tied to \(linkedService.title ?? "service") on \(linkedService.date.formatted(date: .abbreviated, time: .omitted))."
        }

        lastServiceDate = linkedService.date
        if linkedService.mileage > 0 {
            lastServiceMileage = Formatters.mileageText(linkedService.mileage)
        }

        applyRecommendedInterval()
    }

    private func applyRecommendedInterval() {
        let sourceName = reminderSourceName
        guard let template = ManufacturerServiceRecommendations.template(for: sourceName, vehicle: vehicle) else {
            AppErrorCenter.shared.message = "No recommendation found for this reminder yet."
            return
        }

        intervalMonths = template.intervalMonths > 0 ? String(template.intervalMonths) : ""
        intervalMiles = template.intervalMiles > 0 ? Formatters.mileageText(template.intervalMiles) : ""
        AppFeedbackCenter.shared.show("Recommended interval applied")
    }

    private var reminderSourceName: String {
        if let linkedService = vehicle.log(with: linkedServiceLogID),
           let linkedTitle = linkedService.title,
           !linkedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return linkedTitle
        }
        let trimmedTitle = title
            .replacingOccurrences(of: " Reminder", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Inspection" : trimmedTitle
    }
}
