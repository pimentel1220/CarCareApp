import SwiftUI
import PhotosUI
import CoreData

struct ServiceLogFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var vehicle: Vehicle
    var existingLog: ServiceLog?
    var onOpenParts: (() -> Void)? = nil
    var onOpenReminders: (() -> Void)? = nil

    @State private var serviceType = "Oil Change"
    @State private var customType = ""
    @State private var title = ""
    @State private var date = Date()
    @State private var mileage = ""
    @State private var cost = ""
    @State private var shop = ""
    @State private var details = ""
    @State private var originalMileage: Double = 0
    @State private var createReminder = true
    @State private var reminderMonths = ""
    @State private var reminderMiles = ""

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section("Service") {
                    Picker("Type", selection: $serviceType) {
                        ForEach(ServiceTemplates.popularServiceTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    if serviceType == "Custom" {
                        TextField("Custom Type", text: $customType, axis: .vertical)
                        .lineLimit(1...4)
                    }
                    
                    TextField("Title (optional)", text: $title, axis: .vertical)
                        .lineLimit(1...4)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Mileage", text: $mileage)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Cost", text: $cost)
                        .keyboardType(.decimalPad)
                    TextField("Shop", text: $shop, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section("Details") {
                    TextEditor(text: $details)
                        .frame(height: 120)
                }

                Section("Parts Used") {
                    if let existingLog {
                        if linkedParts(for: existingLog).isEmpty {
                            Text("No parts linked to this service yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(linkedParts(for: existingLog)) { part in
                                Text(part.partName ?? "Part")
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    } else {
                        Text("Save this service first, then link parts from the Parts tab.")
                            .foregroundStyle(.secondary)
                    }

                    Button("View In Parts Tab") {
                        dismiss()
                        onOpenParts?()
                    }
                }

                Section("Reminders Used") {
                    if let existingLog {
                        if linkedReminders(for: existingLog).isEmpty {
                            Text("No reminders linked to this service yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(linkedReminders(for: existingLog)) { reminder in
                                Text(reminder.title ?? "Reminder")
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    } else {
                        Text("Save this service first, then link reminders from the Reminders tab.")
                            .foregroundStyle(.secondary)
                    }

                    Button("View In Reminders Tab") {
                        dismiss()
                        onOpenReminders?()
                    }
                }

                if existingLog == nil {
                    Section("Reminder") {
                        Toggle("Create Reminder", isOn: $createReminder)

                        if createReminder {
                            HStack(spacing: 8) {
                                Text("Source: \(ManufacturerServiceRecommendations.sourceLabel(for: vehicle))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                confidenceBadge
                            }
                            Text(selectedConfidence.description)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let recommendation = selectedRecommendationTemplate {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Why this interval?")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text(recommendationSummary(for: recommendation))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(recommendation.notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                            TextField("Reminder Months", text: $reminderMonths)
                                .keyboardType(.numberPad)
                            TextField("Reminder Miles", text: $reminderMiles)
                                .keyboardType(.numbersAndPunctuation)
                            Button("Use VIN Recommended Interval") {
                                applyDefaultReminderInterval(force: true)
                            }
                        }
                    }
                }

                Section("Receipt Photo") {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        if let data = photoData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            EmptyStateView("Add Photo", systemImage: "doc")
                                .frame(height: 180)
                        }
                    }
                }
            }
            .navigationTitle(existingLog == nil ? "Add Service" : "Edit Service")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if saveLog() {
                            dismiss()
                        }
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
            .onChange(of: serviceType) { _ in
                guard existingLog == nil else { return }
                applyDefaultReminderInterval()
            }
            .onChange(of: customType) { _ in
                guard existingLog == nil, serviceType == "Custom" else { return }
                applyDefaultReminderInterval()
            }
            .onAppear {
                if let log = existingLog {
                    title = log.title ?? ""
                    date = log.date
                    mileage = Formatters.mileageText(log.mileage)
                    cost = log.cost > 0 ? String(format: "%.2f", log.cost) : ""
                    shop = log.shop ?? ""
                    details = log.details ?? ""
                    photoData = log.photoData
                    originalMileage = log.mileage
                } else if vehicle.latestKnownMileage > 0 {
                    mileage = Formatters.mileageText(vehicle.latestKnownMileage)
                }
                if existingLog == nil {
                    applyDefaultReminderInterval(force: true)
                }
            }
        }
    }

    @discardableResult
    private func saveLog() -> Bool {
        let log = existingLog ?? ServiceLog(context: viewContext)
        if existingLog == nil {
            log.id = UUID()
            log.createdAt = Date()
            log.vehicle = vehicle
        }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCustom = customType.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultTitle = serviceType == "Custom" ? (trimmedCustom.isEmpty ? "Custom Service" : trimmedCustom) : serviceType
        log.title = trimmedTitle.isEmpty ? defaultTitle : trimmedTitle
        log.date = date
        let enteredMileage = Formatters.parseMileage(mileage) ?? 0
        guard enteredMileage >= 0 else {
            AppErrorCenter.shared.message = "Mileage cannot be negative."
            return false
        }
        if existingLog != nil {
            if enteredMileage > 0 && enteredMileage < originalMileage {
                AppErrorCenter.shared.message = "Service mileage cannot be lower than the previous value."
                return false
            }
        } else if enteredMileage > 0 && enteredMileage < vehicle.latestKnownMileage {
            AppErrorCenter.shared.message = "Service mileage cannot be lower than the current vehicle mileage."
            return false
        }
        log.mileage = enteredMileage
        let enteredCost = Double(cost.replacingOccurrences(of: ",", with: "")) ?? 0
        guard enteredCost >= 0 else {
            AppErrorCenter.shared.message = "Cost cannot be negative."
            return false
        }
        log.cost = enteredCost
        log.shop = shop.trimmingCharacters(in: .whitespacesAndNewlines)
        log.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
        log.photoData = photoData

        if log.mileage > 0 {
            vehicle.currentMileage = max(vehicle.currentMileage, log.mileage)
        }

        let createdReminder = (existingLog == nil && createReminder) ? createServiceReminder(for: log) : nil

        do {
            try viewContext.save()
            if let createdReminder, createdReminder.dueDate != nil {
                NotificationManager.shared.scheduleNotification(for: createdReminder, vehicleName: vehicle.displayName)
                try? viewContext.save()
            }
            AppFeedbackCenter.shared.show("Service saved")
            return true
        } catch {
            AppErrorCenter.shared.message = error.localizedDescription
            return false
        }
    }

    private func applyDefaultReminderInterval(force: Bool = false) {
        if !force && (!reminderMonths.isEmpty || !reminderMiles.isEmpty) { return }
        guard let template = ManufacturerServiceRecommendations.template(
            for: selectedServiceNameForInterval,
            vehicle: vehicle
        ) else {
            if force {
                reminderMonths = ""
                reminderMiles = ""
            }
            return
        }
        reminderMonths = template.intervalMonths > 0 ? String(template.intervalMonths) : ""
        reminderMiles = template.intervalMiles > 0 ? Formatters.mileageLabel(template.intervalMiles) : ""
    }

    private var selectedServiceNameForInterval: String {
        if serviceType == "Custom" {
            let trimmed = customType.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Custom Service" : trimmed
        }
        return serviceType
    }

    private func createServiceReminder(for log: ServiceLog) -> Reminder? {
        var months = Int16(reminderMonths) ?? 0
        var miles = Formatters.parseMileage(reminderMiles) ?? 0
        if (months <= 0 && miles <= 0),
           let template = ManufacturerServiceRecommendations.template(
               for: selectedServiceNameForInterval,
               vehicle: vehicle
           ) {
            months = Int16(template.intervalMonths)
            miles = template.intervalMiles
        }
        guard months > 0 || miles > 0 else { return nil }

        let reminder = Reminder(context: viewContext)
        reminder.id = UUID()
        reminder.title = "\(log.title ?? "Service") Reminder"
        reminder.details = "Auto-created from service on \(log.date.formatted(date: .abbreviated, time: .omitted))."
        reminder.lastServiceDate = log.date
        reminder.lastServiceMileage = log.mileage
        reminder.repeatIntervalMonths = months
        reminder.repeatIntervalMiles = miles
        reminder.isCompleted = false
        reminder.vehicle = vehicle
        reminder.linkedServiceLogID = log.id

        if months > 0 {
            reminder.dueDate = Calendar.current.date(byAdding: .month, value: Int(months), to: log.date)
        }
        if miles > 0 {
            reminder.dueMileage = log.mileage > 0 ? log.mileage + miles : vehicle.latestKnownMileage + miles
        }

        return reminder
    }

    private var selectedRecommendationTemplate: ServiceTemplate? {
        ManufacturerServiceRecommendations.template(
            for: selectedServiceNameForInterval,
            vehicle: vehicle
        )
    }

    private var selectedConfidence: RecommendationConfidence {
        ManufacturerServiceRecommendations.confidence(
            for: selectedServiceNameForInterval,
            vehicle: vehicle
        )
    }

    private var confidenceBadge: some View {
        Text("Confidence: \(selectedConfidence.rawValue)")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.15))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
            .accessibilityLabel("Recommendation confidence \(selectedConfidence.rawValue)")
    }

    private var badgeColor: Color {
        switch selectedConfidence {
        case .high:
            return .green
        case .medium:
            return .orange
        case .baseline:
            return .secondary
        }
    }

    private func recommendationSummary(for template: ServiceTemplate) -> String {
        let milesText = template.intervalMiles > 0 ? "\(Formatters.mileageLabel(template.intervalMiles)) miles" : nil
        let monthsText = template.intervalMonths > 0 ? "\(template.intervalMonths) months" : nil
        let parts = [milesText, monthsText].compactMap { $0 }
        if parts.isEmpty { return "No fixed interval. Use condition-based maintenance." }
        return "Recommended every " + parts.joined(separator: " or ")
    }

    private func linkedParts(for log: ServiceLog) -> [PartReplacement] {
        vehicle.sortedParts.filter { $0.linkedServiceLogID == log.id }
    }

    private func linkedReminders(for log: ServiceLog) -> [Reminder] {
        vehicle.sortedReminders.filter { $0.linkedServiceLogID == log.id }
    }
}
