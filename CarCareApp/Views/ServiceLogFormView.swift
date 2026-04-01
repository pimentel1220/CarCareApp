import SwiftUI
import PhotosUI
import CoreData

struct ServiceLogFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var vehicle: Vehicle
    var existingLog: ServiceLog?
    var initialServiceType: String? = nil
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
    @State private var showingReceiptPreview = false
    @State private var receiptExportURL: URL?

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

                    HStack {
                        Button("Use Current Mileage") {
                            mileage = Formatters.mileageText(vehicle.latestKnownMileage)
                        }
                        .disabled(vehicle.latestKnownMileage <= 0)

                        Spacer()

                        Button("Use Last Shop") {
                            shop = mostRecentShop
                        }
                        .disabled(mostRecentShop.isEmpty)
                    }
                    .font(.caption)
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
                    if let data = photoData, let image = UIImage(data: data) {
                        Button {
                            showingReceiptPreview = true
                        } label: {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(alignment: .bottomTrailing) {
                                    Label("Tap to View", systemImage: "arrow.up.left.and.arrow.down.right")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.ultraThinMaterial, in: Capsule())
                                        .padding(10)
                                }
                        }
                        .buttonStyle(.plain)

                        HStack {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Label("Replace Photo", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                showingReceiptPreview = true
                            } label: {
                                Label("View Full Screen", systemImage: "photo")
                            }
                            .buttonStyle(.bordered)
                        }

                        HStack {
                            if let receiptExportURL {
                                ShareLink(item: receiptExportURL) {
                                    Label("Download / Share", systemImage: "square.and.arrow.down")
                                }
                                .buttonStyle(.borderedProminent)
                            }

                            Button(role: .destructive) {
                                photoData = nil
                                selectedPhotoItem = nil
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            EmptyStateView("Add Photo", systemImage: "doc")
                                .frame(height: 180)
                        }
                        .buttonStyle(.plain)
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
            .onChange(of: photoData) { _ in
                refreshReceiptExportURL()
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
                } else {
                    if let initialServiceType,
                       ServiceTemplates.popularServiceTypes.contains(initialServiceType) {
                        serviceType = initialServiceType
                    }
                    if vehicle.latestKnownMileage > 0 {
                        mileage = Formatters.mileageText(vehicle.latestKnownMileage)
                    }
                }
                if existingLog == nil {
                    applyDefaultReminderInterval(force: true)
                }
                refreshReceiptExportURL()
            }
            .fullScreenCover(isPresented: $showingReceiptPreview) {
                ReceiptPreviewView(photoData: photoData, exportURL: receiptExportURL)
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

    private var mostRecentShop: String {
        vehicle.sortedLogs
            .compactMap { $0.shop?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
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

    private func refreshReceiptExportURL() {
        guard let photoData else {
            receiptExportURL = nil
            return
        }

        do {
            let receiptID = existingLog?.id.uuidString ?? UUID().uuidString
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("service-receipt-\(receiptID).jpg")
            try photoData.write(to: tempURL, options: .atomic)
            receiptExportURL = tempURL
        } catch {
            receiptExportURL = nil
        }
    }
}

private struct ReceiptPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let photoData: Data?
    let exportURL: URL?

    var body: some View {
        NavigationStack {
            Group {
                if let photoData, let image = UIImage(data: photoData) {
                    ZoomableReceiptImage(image: image)
                        .background(Color.black)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No Receipt Photo")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ZoomableReceiptImage: View {
    let image: UIImage
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .gesture(dragGesture)
                .simultaneousGesture(magnificationGesture)
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut) {
                        if scale > 1 {
                            resetZoom()
                        } else {
                            scale = 2
                        }
                    }
                }
        }
        .background(Color.black)
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let proposedScale = lastScale * value
                scale = min(max(proposedScale, 1), 5)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 {
                    resetZoom()
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                if scale > 1 {
                    lastOffset = offset
                } else {
                    resetZoom()
                }
            }
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}
