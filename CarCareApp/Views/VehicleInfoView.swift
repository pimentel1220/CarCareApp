import SwiftUI
import CoreData
import UniformTypeIdentifiers
import UIKit

struct VehicleInfoView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var vehicle: Vehicle

    @State private var showingEdit = false
    @State private var mileageText = ""
    @State private var isDecodingVIN = false
    @State private var recommendationStyle = RecommendationPreferences.style
    @State private var showApplyConfirm = false
    @State private var showUndoConfirm = false
    @State private var showBackupExporter = false
    @State private var backupDocument: VehicleBackupDocument?
    @State private var showBackupImporter = false
    @State private var showImportConfirm = false
    @State private var pendingImportData: Data?
    @State private var pendingImportPayload: VehicleBackupPayload?
    @State private var replaceExistingOnImport = false
    @State private var autoBackupMode = AutoBackupMode.load()
    @State private var autoBackupChangeThreshold = AutoBackupMode.loadChangeThreshold()
    @State private var showAutoBackupPrompt = false
    @State private var autoBackupPromptMessage = ""
    @State private var isSyncingManufacturerSchedule = false
    @State private var isTestingScheduleProvider = false
    @State private var providerConnectionStatus: ProviderConnectionStatus?
    @State private var scheduleProviderSettings = ScheduleProviderSettings.load()

    var body: some View {
        List {
            Section("Overview") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(vehicle.displayName)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Current Mileage")
                    Spacer()
                    Text(vehicle.latestKnownMileage > 0 ? Formatters.mileageLabel(vehicle.latestKnownMileage) : "Not set")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Active Reminders")
                    Spacer()
                    Text("\(vehicle.activeReminders.count)")
                        .foregroundStyle(.secondary)
                }
                Button("Edit Vehicle") {
                    showingEdit = true
                }
            }

            Section("Vehicle Info") {
                InfoRow(label: "Year", value: vehicle.year > 0 ? String(vehicle.year) : nil)
                InfoRow(label: "Make", value: vehicle.make)
                InfoRow(label: "Model", value: vehicle.model)
                InfoRow(label: "Trim", value: vehicle.trim)
                InfoRow(label: "Engine", value: vehicle.engine)
                InfoRow(label: "VIN", value: vehicle.vin)
                InfoRow(label: "Plate", value: vehicle.plate)
            }

            Section("Notes") {
                Text(vehicle.notes ?? "No notes yet")
                    .foregroundStyle(.secondary)
            }

            Section("Update Mileage") {
                TextField("Mileage", text: $mileageText)
                    .keyboardType(.numbersAndPunctuation)

                Button("Save Mileage") {
                    if let mileage = Formatters.parseMileage(mileageText) {
                        guard mileage >= vehicle.latestKnownMileage else {
                            AppErrorCenter.shared.message = "Mileage cannot be lower than the current value."
                            return
                        }
                        vehicle.currentMileage = mileage
                        saveContext()
                    }
                }
            }

            Section("Actions") {
                Button("Edit Vehicle") {
                    showingEdit = true
                }
                Button(isDecodingVIN ? "Decoding VIN..." : "Decode VIN") {
                    decodeVIN()
                }
                .disabled(isDecodingVIN)
                Text("VIN decoding sends the VIN to a secure external lookup service to fill vehicle details.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section("Backups") {
                Text("Backups include ownership records and optional photos. Provider credentials and developer settings are never exported.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Export Vehicle Backup") {
                    exportBackup()
                }
                Button("Import Vehicle Backup") {
                    showBackupImporter = true
                }
                if let lastBackupExportDate {
                    Text("Last backup exported: \(lastBackupExportDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Developer Settings") {
                NavigationLink {
                    VehicleDeveloperSettingsView(
                        vehicle: vehicle,
                        recommendationStyle: $recommendationStyle,
                        autoBackupMode: $autoBackupMode,
                        autoBackupChangeThreshold: $autoBackupChangeThreshold,
                        replaceExistingOnImport: $replaceExistingOnImport,
                        isSyncingManufacturerSchedule: $isSyncingManufacturerSchedule,
                        isTestingScheduleProvider: $isTestingScheduleProvider,
                        providerConnectionStatus: $providerConnectionStatus,
                        scheduleProviderSettings: $scheduleProviderSettings,
                        hasUndoSnapshot: hasUndoSnapshot,
                        hasStyleHistory: hasStyleHistory,
                        activeReminderCountForStyleApply: activeReminderCountForStyleApply,
                        undoSnapshotReminderCount: undoSnapshotReminderCount,
                        lastStyleApplyDate: lastStyleApplyDate,
                        lastManufacturerSyncDate: ManufacturerScheduleSync.lastSyncedAt(for: vehicle),
                        lastBackupExportDate: lastBackupExportDate,
                        onSyncManufacturerSchedule: syncManufacturerSchedule,
                        onTestProviderConnection: testProviderConnection,
                        onUseCarMDPreset: {
                            scheduleProviderSettings.applyCarMDPreset()
                            scheduleProviderSettings.save()
                            providerConnectionStatus = nil
                            AppFeedbackCenter.shared.show("CarMD preset applied")
                        },
                        onClearStoredCredentials: {
                            scheduleProviderSettings.clearStoredCredentials()
                            scheduleProviderSettings.save()
                            providerConnectionStatus = nil
                            AppFeedbackCenter.shared.show("Stored credentials cleared")
                        },
                        onApplyStyle: { showApplyConfirm = true },
                        onUndoStyle: { showUndoConfirm = true },
                        onClearStyleHistory: clearStyleHistory,
                        providerStatusText: providerStatusText,
                        providerStatusColor: providerStatusColor
                    )
                } label: {
                    Label("Open Developer Settings", systemImage: "gearshape.2")
                }
                Text("Advanced sync, provider setup, replace-import mode, style tools, and auto-backup live here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showingEdit = true
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            VehicleFormView(vehicle: vehicle)
        }
        .onAppear {
            mileageText = Formatters.mileageText(vehicle.latestKnownMileage)
            recommendationStyle = RecommendationPreferences.style
            autoBackupMode = AutoBackupMode.load()
            autoBackupChangeThreshold = AutoBackupMode.loadChangeThreshold()
            scheduleProviderSettings = ScheduleProviderSettings.load()
            evaluateAutoBackupPrompt()
        }
        .onChange(of: recommendationStyle) { newValue in
            RecommendationPreferences.style = newValue
        }
        .onChange(of: autoBackupMode) { newValue in
            AutoBackupMode.save(newValue)
        }
        .onChange(of: autoBackupChangeThreshold) { newValue in
            AutoBackupMode.saveChangeThreshold(newValue)
        }
        .onChange(of: scheduleProviderSettings.provider) { _ in
            scheduleProviderSettings.save()
            providerConnectionStatus = nil
        }
        .onChange(of: scheduleProviderSettings.endpointTemplate) { _ in
            scheduleProviderSettings.save()
            providerConnectionStatus = nil
        }
        .onChange(of: scheduleProviderSettings.authMode) { _ in
            scheduleProviderSettings.save()
            providerConnectionStatus = nil
        }
        .onChange(of: scheduleProviderSettings.authToken) { _ in
            scheduleProviderSettings.save()
            providerConnectionStatus = nil
        }
        .onChange(of: scheduleProviderSettings.partnerToken) { _ in
            scheduleProviderSettings.save()
            providerConnectionStatus = nil
        }
        .onChange(of: scheduleProviderSettings.authHeaderName) { _ in
            scheduleProviderSettings.save()
            providerConnectionStatus = nil
        }
        .onChange(of: scheduleProviderSettings.authQueryKey) { _ in
            scheduleProviderSettings.save()
            providerConnectionStatus = nil
        }
        .alert("Apply New Style?", isPresented: $showApplyConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Apply", role: .destructive) {
                applyStyleToActiveReminders()
            }
        } message: {
            Text("This will update \(activeReminderCountForStyleApply) active reminder(s) for this vehicle to the current recommendation style.")
        }
        .alert("Undo Last Style Re-Apply?", isPresented: $showUndoConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Undo", role: .destructive) {
                undoLastStyleReapply()
            }
        } message: {
            Text("This will restore up to \(undoSnapshotReminderCount) reminder(s) from the last style update snapshot.")
        }
        .fileExporter(
            isPresented: $showBackupExporter,
            document: backupDocument,
            contentType: .json,
            defaultFilename: backupFilename
        ) { result in
            switch result {
            case .success:
                recordLastBackupExportDate(Date())
                recordBackupSnapshot()
                AppFeedbackCenter.shared.show("Backup exported")
            case .failure(let error):
                AppErrorCenter.shared.message = userSafeBackupMessage(for: error, defaultMessage: "Backup export failed.")
            }
        }
        .fileImporter(
            isPresented: $showBackupImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .alert("Import Backup?", isPresented: $showImportConfirm) {
            Button("Cancel", role: .cancel) {
                pendingImportData = nil
                pendingImportPayload = nil
            }
            Button("Import", role: .destructive) {
                applyPendingImport()
            }
        } message: {
            Text(importPreviewText)
        }
        .alert("Backup Recommended", isPresented: $showAutoBackupPrompt) {
            Button("Not now", role: .cancel) {}
            Button("Export Now") {
                exportBackup()
            }
        } message: {
            Text(autoBackupPromptMessage)
        }
    }

    private func saveContext(successMessage: String = "Vehicle updated") {
        do {
            try viewContext.save()
            AppFeedbackCenter.shared.show(successMessage)
        } catch {
            AppErrorCenter.shared.message = "Could not save changes right now."
        }
    }

    private func decodeVIN() {
        let cleanedVIN = VINDecoder.sanitize(vehicle.vin ?? "")
        guard !cleanedVIN.isEmpty else {
            AppErrorCenter.shared.message = "Add a VIN first."
            return
        }

        vehicle.vin = cleanedVIN
        isDecodingVIN = true

        Task {
            do {
                let decoded = try await VINDecoder.decode(vin: cleanedVIN)
                await MainActor.run {
                    if let year = decoded.year, year > 0 {
                        vehicle.year = Int16(year)
                    }
                    if let make = decoded.make { vehicle.make = make }
                    if let model = decoded.model { vehicle.model = model }
                    if let trim = decoded.trim { vehicle.trim = trim }
                    if let engine = decoded.engine { vehicle.engine = engine }
                    saveContext(successMessage: "Vehicle updated")
                    isDecodingVIN = false
                    AppFeedbackCenter.shared.show("VIN decoded")
                }
            } catch {
                await MainActor.run {
                    isDecodingVIN = false
                    AppErrorCenter.shared.message = userSafeVINMessage(for: error)
                }
            }
        }
    }

    private func syncManufacturerSchedule() {
        isSyncingManufacturerSchedule = true
        providerConnectionStatus = nil
        Task {
            do {
                _ = try await ManufacturerScheduleSync.sync(for: vehicle)
                await MainActor.run {
                    isSyncingManufacturerSchedule = false
                    AppFeedbackCenter.shared.show("Manufacturer schedule synced")
                }
            } catch {
                await MainActor.run {
                    isSyncingManufacturerSchedule = false
                    AppErrorCenter.shared.message = ManufacturerScheduleSync.userSafeMessage(for: error)
                }
            }
        }
    }

    private func testProviderConnection() {
        isTestingScheduleProvider = true
        providerConnectionStatus = nil
        Task {
            let status = await ManufacturerScheduleSync.testConnection(for: vehicle)
            await MainActor.run {
                providerConnectionStatus = status
                isTestingScheduleProvider = false
            }
        }
    }

    private func providerStatusText(_ status: ProviderConnectionStatus) -> String {
        switch status {
        case .connected(let message):
            return "Connected: \(message)"
        case .authFailed(let message):
            return "Auth Failed: \(message)"
        case .invalidResponse(let message):
            return "Invalid Response: \(message)"
        case .failed(let message):
            return "Connection Failed: \(message)"
        }
    }

    private func providerStatusColor(_ status: ProviderConnectionStatus) -> Color {
        switch status {
        case .connected:
            return .green
        case .authFailed:
            return .red
        case .invalidResponse:
            return .orange
        case .failed:
            return .secondary
        }
    }

    private func applyStyleToActiveReminders() {
        let activeReminders = vehicle.sortedReminders.filter { !$0.isCompleted }
        guard !activeReminders.isEmpty else {
            AppFeedbackCenter.shared.show("No active reminders to update")
            return
        }

        var snapshots: [ReminderIntervalSnapshot] = []
        var updatedCount = 0
        for reminder in activeReminders {
            let serviceName = baseServiceName(for: reminder)
            guard let template = ManufacturerServiceRecommendations.template(for: serviceName, vehicle: vehicle) else {
                continue
            }

            snapshots.append(
                ReminderIntervalSnapshot(
                    reminderID: reminder.id,
                    repeatIntervalMonths: reminder.repeatIntervalMonths,
                    repeatIntervalMiles: reminder.repeatIntervalMiles,
                    dueDate: reminder.dueDate,
                    dueMileage: reminder.dueMileage,
                    details: reminder.details
                )
            )

            let oldMonths = reminder.repeatIntervalMonths
            let oldMiles = reminder.repeatIntervalMiles
            reminder.repeatIntervalMonths = Int16(template.intervalMonths)
            reminder.repeatIntervalMiles = template.intervalMiles

            if reminder.repeatIntervalMonths > 0 {
                let anchorDate = reminder.lastServiceDate ?? Date()
                reminder.dueDate = Calendar.current.date(byAdding: .month, value: Int(reminder.repeatIntervalMonths), to: anchorDate)
            } else {
                reminder.dueDate = nil
            }

            if reminder.repeatIntervalMiles > 0 {
                let anchorMileage = reminder.lastServiceMileage > 0 ? reminder.lastServiceMileage : vehicle.latestKnownMileage
                reminder.dueMileage = anchorMileage + reminder.repeatIntervalMiles
            } else {
                reminder.dueMileage = 0
            }

            appendReminderAuditLog(
                reminder: reminder,
                oldMonths: oldMonths,
                oldMiles: oldMiles,
                newMonths: reminder.repeatIntervalMonths,
                newMiles: reminder.repeatIntervalMiles
            )
            NotificationManager.shared.scheduleNotification(for: reminder, vehicleName: vehicle.displayName)
            updatedCount += 1
        }

        if updatedCount == 0 {
            AppFeedbackCenter.shared.show("No matching reminders to update")
            return
        }

        saveUndoSnapshot(snapshots)
        recordLastStyleApplyDate(Date())
        saveContext(successMessage: "Updated \(updatedCount) reminder(s)")
    }

    private func undoLastStyleReapply() {
        guard let snapshots = loadUndoSnapshot(), !snapshots.isEmpty else {
            AppFeedbackCenter.shared.show("No style update to undo")
            return
        }

        let remindersByID = Dictionary(uniqueKeysWithValues: vehicle.sortedReminders.map { ($0.id, $0) })
        var restoredCount = 0

        for snapshot in snapshots {
            guard let reminder = remindersByID[snapshot.reminderID] else { continue }
            let oldMonths = reminder.repeatIntervalMonths
            let oldMiles = reminder.repeatIntervalMiles

            reminder.repeatIntervalMonths = snapshot.repeatIntervalMonths
            reminder.repeatIntervalMiles = snapshot.repeatIntervalMiles
            reminder.dueDate = snapshot.dueDate
            reminder.dueMileage = snapshot.dueMileage
            reminder.details = snapshot.details

            appendUndoAuditLog(
                reminder: reminder,
                oldMonths: oldMonths,
                oldMiles: oldMiles,
                restoredMonths: snapshot.repeatIntervalMonths,
                restoredMiles: snapshot.repeatIntervalMiles
            )

            NotificationManager.shared.removeNotification(for: reminder)
            NotificationManager.shared.scheduleNotification(for: reminder, vehicleName: vehicle.displayName)
            restoredCount += 1
        }

        clearUndoSnapshot()

        guard restoredCount > 0 else {
            AppFeedbackCenter.shared.show("No reminders were restored")
            return
        }
        saveContext(successMessage: "Undid style update for \(restoredCount) reminder(s)")
    }

    private func baseServiceName(for reminder: Reminder) -> String {
        let raw = (reminder.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "Inspection" }
        if raw.lowercased().hasSuffix(" reminder") {
            return String(raw.dropLast(" reminder".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return raw
    }

    private func appendReminderAuditLog(
        reminder: Reminder,
        oldMonths: Int16,
        oldMiles: Double,
        newMonths: Int16,
        newMiles: Double
    ) {
        let oldInterval = intervalText(months: Int(oldMonths), miles: oldMiles)
        let newInterval = intervalText(months: Int(newMonths), miles: newMiles)
        guard oldInterval != newInterval else { return }

        let stamp = Date().formatted(date: .abbreviated, time: .shortened)
        let style = RecommendationPreferences.style.title
        let logLine = "[\(stamp)] Style re-apply (\(style)): \(oldInterval) -> \(newInterval)"
        let existing = reminder.details?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        reminder.details = existing.isEmpty ? logLine : "\(existing)\n\(logLine)"
    }

    private func intervalText(months: Int, miles: Double) -> String {
        let monthsText = months > 0 ? "\(months) mo" : nil
        let milesText = miles > 0 ? "\(Formatters.mileageLabel(miles)) mi" : nil
        let parts = [monthsText, milesText].compactMap { $0 }
        return parts.isEmpty ? "No interval" : parts.joined(separator: " / ")
    }

    private func appendUndoAuditLog(
        reminder: Reminder,
        oldMonths: Int16,
        oldMiles: Double,
        restoredMonths: Int16,
        restoredMiles: Double
    ) {
        let previous = intervalText(months: Int(oldMonths), miles: oldMiles)
        let restored = intervalText(months: Int(restoredMonths), miles: restoredMiles)
        guard previous != restored else { return }

        let stamp = Date().formatted(date: .abbreviated, time: .shortened)
        let logLine = "[\(stamp)] Undo style re-apply: \(previous) -> \(restored)"
        let existing = reminder.details?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        reminder.details = existing.isEmpty ? logLine : "\(existing)\n\(logLine)"
    }

    private var undoSnapshotKey: String {
        "recommendation.undo.\(vehicle.id.uuidString)"
    }

    private var lastStyleApplyKey: String {
        "recommendation.lastApply.\(vehicle.id.uuidString)"
    }

    private var hasUndoSnapshot: Bool {
        UserDefaults.standard.data(forKey: undoSnapshotKey) != nil
    }

    private var activeReminderCountForStyleApply: Int {
        vehicle.sortedReminders.filter { !$0.isCompleted }.count
    }

    private var undoSnapshotReminderCount: Int {
        loadUndoSnapshot()?.count ?? 0
    }

    private var hasStyleHistory: Bool {
        hasUndoSnapshot || lastStyleApplyDate != nil
    }

    private func saveUndoSnapshot(_ snapshots: [ReminderIntervalSnapshot]) {
        guard !snapshots.isEmpty else { return }
        if let data = try? JSONEncoder().encode(snapshots) {
            UserDefaults.standard.set(data, forKey: undoSnapshotKey)
        }
    }

    private func loadUndoSnapshot() -> [ReminderIntervalSnapshot]? {
        guard let data = UserDefaults.standard.data(forKey: undoSnapshotKey) else { return nil }
        return try? JSONDecoder().decode([ReminderIntervalSnapshot].self, from: data)
    }

    private func clearUndoSnapshot() {
        UserDefaults.standard.removeObject(forKey: undoSnapshotKey)
    }

    private var lastStyleApplyDate: Date? {
        UserDefaults.standard.object(forKey: lastStyleApplyKey) as? Date
    }

    private func recordLastStyleApplyDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastStyleApplyKey)
    }

    private func clearStyleHistory() {
        clearUndoSnapshot()
        UserDefaults.standard.removeObject(forKey: lastStyleApplyKey)
        AppFeedbackCenter.shared.show("Style history cleared")
    }

    private var backupFilename: String {
        "carcare-backup-\(backupTimestamp())"
    }

    private func backupTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: Date())
    }

    private var lastBackupExportKey: String {
        "backup.lastExport.\(vehicle.id.uuidString)"
    }

    private var lastBackupExportDate: Date? {
        UserDefaults.standard.object(forKey: lastBackupExportKey) as? Date
    }

    private func recordLastBackupExportDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastBackupExportKey)
    }

    private var backupRecordSnapshotKey: String {
        "backup.recordSnapshot.\(vehicle.id.uuidString)"
    }

    private var backupRecordSnapshot: Int {
        UserDefaults.standard.integer(forKey: backupRecordSnapshotKey)
    }

    private func recordBackupSnapshot() {
        UserDefaults.standard.set(currentTotalRecordCount, forKey: backupRecordSnapshotKey)
    }

    private var currentTotalRecordCount: Int {
        vehicle.sortedLogs.count + vehicle.sortedReminders.count + vehicle.sortedParts.count
    }

    private func evaluateAutoBackupPrompt() {
        switch autoBackupMode {
        case .off:
            return
        case .weekly, .biweekly, .monthly:
            guard let lastBackup = lastBackupExportDate else {
                autoBackupPromptMessage = "No backup found yet. Export a backup now?"
                showAutoBackupPrompt = true
                return
            }
            let days = autoBackupMode.dayInterval
            guard let dueDate = Calendar.current.date(byAdding: .day, value: days, to: lastBackup) else { return }
            if Date() >= dueDate {
                autoBackupPromptMessage = "Your last backup was \(lastBackup.formatted(date: .abbreviated, time: .shortened)). Export a new backup now?"
                showAutoBackupPrompt = true
            }
        case .changes:
            guard lastBackupExportDate != nil else {
                autoBackupPromptMessage = "No backup found yet. Export a backup now?"
                showAutoBackupPrompt = true
                return
            }
            let delta = max(0, currentTotalRecordCount - backupRecordSnapshot)
            if delta >= autoBackupChangeThreshold {
                autoBackupPromptMessage = "\(delta) new records were added since your last backup. Export now?"
                showAutoBackupPrompt = true
            }
        }
    }

    private func exportBackup() {
        do {
            let data = try VehicleBackupCodec.exportData(from: vehicle)
            backupDocument = VehicleBackupDocument(data: data)
            showBackupExporter = true
        } catch {
            AppErrorCenter.shared.message = userSafeBackupMessage(for: error, defaultMessage: "Backup export failed.")
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            AppErrorCenter.shared.message = userSafeBackupMessage(for: error, defaultMessage: "Backup import failed.")
        case .success(let urls):
            guard let url = urls.first else { return }
            importBackup(from: url)
        }
    }

    private func importBackup(from url: URL) {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let payload = try VehicleBackupCodec.decodePayload(data)
            pendingImportData = data
            pendingImportPayload = payload
            showImportConfirm = true
        } catch {
            AppErrorCenter.shared.message = userSafeBackupMessage(for: error, defaultMessage: "Backup import failed.")
        }
    }

    private func applyPendingImport() {
        guard let data = pendingImportData else { return }
        do {
            let summary = try VehicleBackupCodec.importData(
                data,
                into: vehicle,
                context: viewContext,
                replaceExisting: replaceExistingOnImport
            )
            pendingImportData = nil
            pendingImportPayload = nil
            saveContext(successMessage: "Imported \(summary.logs) service(s), \(summary.reminders) reminder(s), \(summary.parts) part(s)")
        } catch {
            viewContext.rollback()
            pendingImportData = nil
            pendingImportPayload = nil
            AppErrorCenter.shared.message = userSafeBackupMessage(for: error, defaultMessage: "Backup import failed.")
        }
    }

    private var importPreviewText: String {
        guard let payload = pendingImportPayload else {
            return "This will import backup data into the current vehicle."
        }
        let vehicleName = payload.vehicle.displayName
        if replaceExistingOnImport {
            return """
            Mode: Replace existing data
            Warning: This will delete current data first.
            Will delete now: \(currentLogCount) service(s), \(currentReminderCount) reminder(s), \(currentPartCount) part(s)
            Import file vehicle: \(vehicleName)
            Import file items: \(payload.logs.count) service(s), \(payload.reminders.count) reminder(s), \(payload.parts.count) part(s)
            """
        }
        return """
        Mode: Merge with existing data
        Import file vehicle: \(vehicleName)
        Import file items: \(payload.logs.count) service(s), \(payload.reminders.count) reminder(s), \(payload.parts.count) part(s)
        """
    }

    private var currentLogCount: Int {
        vehicle.sortedLogs.count
    }

    private var currentReminderCount: Int {
        vehicle.sortedReminders.count
    }

    private var currentPartCount: Int {
        vehicle.sortedParts.count
    }

    private func userSafeBackupMessage(for error: Error, defaultMessage: String) -> String {
        if let backupError = error as? VehicleBackupError {
            return backupError.localizedDescription
        }
        return defaultMessage
    }

    private func userSafeVINMessage(for error: Error) -> String {
        if let vinError = error as? VINDecodeError {
            return vinError.localizedDescription
        }
        return "VIN decode failed. Please try again in a moment."
    }
}

private struct ReminderIntervalSnapshot: Codable {
    let reminderID: UUID
    let repeatIntervalMonths: Int16
    let repeatIntervalMiles: Double
    let dueDate: Date?
    let dueMileage: Double
    let details: String?
}

private enum AutoBackupMode: String, CaseIterable, Identifiable {
    case off
    case weekly
    case biweekly
    case monthly
    case changes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 Weeks"
        case .monthly: return "Monthly"
        case .changes: return "By Record Changes"
        }
    }

    var dayInterval: Int {
        switch self {
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly: return 30
        case .off, .changes: return 0
        }
    }

    private static let modeKey = "backup.auto.mode"
    private static let changeThresholdKey = "backup.auto.changeThreshold"

    static func load() -> AutoBackupMode {
        let raw = UserDefaults.standard.string(forKey: modeKey) ?? AutoBackupMode.off.rawValue
        return AutoBackupMode(rawValue: raw) ?? .off
    }

    static func save(_ mode: AutoBackupMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: modeKey)
    }

    static func loadChangeThreshold() -> Int {
        let value = UserDefaults.standard.integer(forKey: changeThresholdKey)
        return value > 0 ? value : 20
    }

    static func saveChangeThreshold(_ threshold: Int) {
        UserDefaults.standard.set(threshold, forKey: changeThresholdKey)
    }
}

private struct VehicleDeveloperSettingsView: View {
    @ObservedObject var vehicle: Vehicle
    @Binding var recommendationStyle: RecommendationStyle
    @Binding var autoBackupMode: AutoBackupMode
    @Binding var autoBackupChangeThreshold: Int
    @Binding var replaceExistingOnImport: Bool
    @Binding var isSyncingManufacturerSchedule: Bool
    @Binding var isTestingScheduleProvider: Bool
    @Binding var providerConnectionStatus: ProviderConnectionStatus?
    @Binding var scheduleProviderSettings: ScheduleProviderSettings

    let hasUndoSnapshot: Bool
    let hasStyleHistory: Bool
    let activeReminderCountForStyleApply: Int
    let undoSnapshotReminderCount: Int
    let lastStyleApplyDate: Date?
    let lastManufacturerSyncDate: Date?
    let lastBackupExportDate: Date?
    let onSyncManufacturerSchedule: () -> Void
    let onTestProviderConnection: () -> Void
    let onUseCarMDPreset: () -> Void
    let onClearStoredCredentials: () -> Void
    let onApplyStyle: () -> Void
    let onUndoStyle: () -> Void
    let onClearStyleHistory: () -> Void
    let providerStatusText: (ProviderConnectionStatus) -> String
    let providerStatusColor: (ProviderConnectionStatus) -> Color

    var body: some View {
        List {
            Section("Recommendation Style") {
                Picker("Style", selection: $recommendationStyle) {
                    ForEach(RecommendationStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Text(recommendationStyle.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Apply New Style to Existing Active Reminders") {
                    onApplyStyle()
                }

                Text("Will affect \(activeReminderCountForStyleApply) active reminder(s).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Button("Undo Last Style Re-Apply") {
                    onUndoStyle()
                }
                .disabled(!hasUndoSnapshot)

                Text("Undo snapshot covers \(undoSnapshotReminderCount) reminder(s).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Button("Clear Style History", role: .destructive) {
                    onClearStyleHistory()
                }
                .disabled(!hasStyleHistory)

                if let lastStyleApplyDate {
                    Text("Last style apply: \(lastStyleApplyDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Manufacturer Schedule") {
                Button(isSyncingManufacturerSchedule ? "Syncing Manufacturer Schedule..." : "Sync Manufacturer Schedule by VIN") {
                    onSyncManufacturerSchedule()
                }
                .disabled(isSyncingManufacturerSchedule)

                if let lastManufacturerSyncDate {
                    Text("Last manufacturer sync: \(lastManufacturerSyncDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Schedule Provider") {
                Text("Credentials are stored locally on this device using Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Only HTTPS endpoints are allowed for provider sync and testing.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Picker("Schedule Source", selection: $scheduleProviderSettings.provider) {
                    ForEach(ScheduleProviderType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }

                Button("Use CarMD Preset") {
                    onUseCarMDPreset()
                }

                Button("Clear Stored Credentials", role: .destructive) {
                    onClearStoredCredentials()
                }
                .disabled(
                    scheduleProviderSettings.authToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    scheduleProviderSettings.partnerToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

                if scheduleProviderSettings.provider == .genericREST || scheduleProviderSettings.provider == .auto {
                    TextField("Provider URL (use {vin})", text: $scheduleProviderSettings.endpointTemplate, axis: .vertical)
                        .lineLimit(1...3)
                    Picker("Auth", selection: $scheduleProviderSettings.authMode) {
                        ForEach(ScheduleAuthMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    if scheduleProviderSettings.authMode == .bearer {
                        SecureField("Bearer Token", text: $scheduleProviderSettings.authToken)
                    }
                    if scheduleProviderSettings.authMode == .header {
                        TextField("Header Name", text: $scheduleProviderSettings.authHeaderName)
                        SecureField("Header Value", text: $scheduleProviderSettings.authToken)
                    }
                    if scheduleProviderSettings.authMode == .queryParam {
                        TextField("Query Key", text: $scheduleProviderSettings.authQueryKey)
                        SecureField("Query Value", text: $scheduleProviderSettings.authToken)
                    }
                    if scheduleProviderSettings.authMode == .carScanDualHeader {
                        SecureField("Authorization Header Value", text: $scheduleProviderSettings.authToken)
                        SecureField("Partner-Token Header Value", text: $scheduleProviderSettings.partnerToken)
                    }
                    Text("Example: https://api.example.com/schedule?vin={vin}")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Button(isTestingScheduleProvider ? "Testing Provider..." : "Test Provider Connection") {
                    onTestProviderConnection()
                }
                .disabled(isTestingScheduleProvider)

                if let providerConnectionStatus {
                    Text(providerStatusText(providerConnectionStatus))
                        .font(.caption2)
                        .foregroundStyle(providerStatusColor(providerConnectionStatus))
                }
            }

            Section("Import & Auto Backup") {
                Text("Normal backup export and import live on the main Info screen. Replace mode is kept here because it is destructive.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Replace Existing Data on Import", isOn: $replaceExistingOnImport)
                    .font(.caption)
                Picker("Auto Backup", selection: $autoBackupMode) {
                    ForEach(AutoBackupMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                if autoBackupMode == .changes {
                    Stepper(
                        "Prompt every \(autoBackupChangeThreshold) new records",
                        value: $autoBackupChangeThreshold,
                        in: 5...100,
                        step: 5
                    )
                    .font(.caption)
                }
                if let lastBackupExportDate {
                    Text("Last backup exported: \(lastBackupExportDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Developer Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String?

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value?.isEmpty == false ? value! : "-")
                .foregroundStyle(.secondary)
        }
    }
}

private struct VehicleBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw VehicleBackupError.invalidPayload
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private enum VehicleBackupError: LocalizedError {
    case invalidPayload
    case unsupportedVersion(Int)
    case fileTooLarge
    case tooManyRecords
    case corruptPhotos

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "This backup file is invalid or corrupted."
        case .unsupportedVersion(let version):
            return "This backup file uses unsupported version \(version)."
        case .fileTooLarge:
            return "This backup file is too large to import safely on-device."
        case .tooManyRecords:
            return "This backup file contains too many records to import safely."
        case .corruptPhotos:
            return "One or more backup photos could not be processed safely."
        }
    }
}

private enum VehicleBackupCodec {
    struct ImportSummary {
        let logs: Int
        let reminders: Int
        let parts: Int
    }

    private static let supportedVersions: ClosedRange<Int> = 1...2
    private static let maxBackupBytes = 25 * 1024 * 1024
    private static let maxTotalRecords = 5000
    private static let maxImageBytes = 5 * 1024 * 1024

    static func exportData(from vehicle: Vehicle) throws -> Data {
        let payload = try VehicleBackupPayload(vehicle: vehicle)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        guard data.count <= maxBackupBytes else {
            throw VehicleBackupError.fileTooLarge
        }
        return data
    }

    static func decodePayload(_ data: Data) throws -> VehicleBackupPayload {
        guard data.count <= maxBackupBytes else {
            throw VehicleBackupError.fileTooLarge
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(VehicleBackupPayload.self, from: data)
        try validate(payload)
        return payload
    }

    static func importData(
        _ data: Data,
        into vehicle: Vehicle,
        context: NSManagedObjectContext,
        replaceExisting: Bool
    ) throws -> ImportSummary {
        let payload = try decodePayload(data)

        if replaceExisting {
            vehicle.sortedLogs.forEach(context.delete)
            vehicle.sortedReminders.forEach {
                NotificationManager.shared.removeNotification(for: $0)
                context.delete($0)
            }
            vehicle.sortedParts.forEach(context.delete)
        }

        vehicle.nickname = payload.vehicle.nickname
        vehicle.make = payload.vehicle.make
        vehicle.model = payload.vehicle.model
        vehicle.year = payload.vehicle.year
        vehicle.trim = payload.vehicle.trim
        vehicle.engine = payload.vehicle.engine
        vehicle.vin = payload.vehicle.vin
        vehicle.plate = payload.vehicle.plate
        vehicle.notes = payload.vehicle.notes
        vehicle.photoData = payload.vehicle.photoData
        vehicle.currentMileage = max(vehicle.currentMileage, payload.vehicle.currentMileage)

        let existingLogs = Dictionary(uniqueKeysWithValues: vehicle.sortedLogs.map { ($0.id, $0) })
        for item in payload.logs {
            let log = existingLogs[item.id] ?? ServiceLog(context: context)
            log.id = item.id
            log.title = item.title
            log.date = item.date
            log.mileage = item.mileage
            log.cost = item.cost
            log.shop = item.shop
            log.details = item.details
            log.photoData = item.photoData
            if log.createdAt.timeIntervalSince1970 <= 0 { log.createdAt = item.date }
            log.vehicle = vehicle
        }

        let existingReminders = Dictionary(uniqueKeysWithValues: vehicle.sortedReminders.map { ($0.id, $0) })
        for item in payload.reminders {
            let reminder = existingReminders[item.id] ?? Reminder(context: context)
            reminder.id = item.id
            reminder.title = item.title
            reminder.details = item.details
            reminder.dueDate = item.dueDate
            reminder.dueMileage = item.dueMileage
            reminder.lastServiceDate = item.lastServiceDate
            reminder.lastServiceMileage = item.lastServiceMileage
            reminder.repeatIntervalMonths = item.repeatIntervalMonths
            reminder.repeatIntervalMiles = item.repeatIntervalMiles
            reminder.isCompleted = item.isCompleted
            reminder.notificationID = nil
            reminder.linkedServiceLogID = item.linkedServiceLogID
            reminder.vehicle = vehicle
        }

        let existingParts = Dictionary(uniqueKeysWithValues: vehicle.sortedParts.map { ($0.id, $0) })
        for item in payload.parts {
            let part = existingParts[item.id] ?? PartReplacement(context: context)
            part.id = item.id
            part.partName = item.partName
            part.linkedServiceLogID = item.linkedServiceLogID
            part.date = item.date
            part.mileage = item.mileage
            part.intervalMonths = item.intervalMonths
            part.intervalMiles = item.intervalMiles
            part.notes = item.notes
            if part.createdAt.timeIntervalSince1970 <= 0 { part.createdAt = item.date }
            part.vehicle = vehicle
        }

        vehicle.sortedReminders
            .filter { !$0.isCompleted }
            .forEach { NotificationManager.shared.scheduleNotification(for: $0, vehicleName: vehicle.displayName) }

        return ImportSummary(
            logs: payload.logs.count,
            reminders: payload.reminders.count,
            parts: payload.parts.count
        )
    }

    private static func validate(_ payload: VehicleBackupPayload) throws {
        guard supportedVersions.contains(payload.version) else {
            throw VehicleBackupError.unsupportedVersion(payload.version)
        }
        let totalRecords = payload.logs.count + payload.reminders.count + payload.parts.count
        guard totalRecords <= maxTotalRecords else {
            throw VehicleBackupError.tooManyRecords
        }
        guard imageDataIsSafe(payload.vehicle.photoData) else {
            throw VehicleBackupError.corruptPhotos
        }
        guard payload.logs.allSatisfy({ imageDataIsSafe($0.photoData) }) else {
            throw VehicleBackupError.corruptPhotos
        }
    }

    private static func imageDataIsSafe(_ data: Data?) -> Bool {
        guard let data else { return true }
        return data.count <= maxImageBytes
    }
}

private struct VehicleBackupPayload: Codable {
    let version: Int
    let exportedAt: Date
    let vehicle: VehicleRecord
    let logs: [ServiceLogRecord]
    let reminders: [ReminderRecord]
    let parts: [PartRecord]

    init(vehicle: Vehicle) throws {
        version = 2
        exportedAt = Date()
        self.vehicle = try VehicleRecord(vehicle: vehicle)
        logs = try vehicle.sortedLogs.map { try ServiceLogRecord(log: $0) }
        reminders = vehicle.sortedReminders.map { ReminderRecord(reminder: $0) }
        parts = vehicle.sortedParts.map { PartRecord(part: $0) }
    }
}

private struct VehicleRecord: Codable {
    let nickname: String?
    let make: String?
    let model: String?
    let year: Int16
    let trim: String?
    let engine: String?
    let vin: String?
    let plate: String?
    let notes: String?
    let photoData: Data?
    let currentMileage: Double

    init(vehicle: Vehicle) throws {
        nickname = vehicle.nickname
        make = vehicle.make
        model = vehicle.model
        year = vehicle.year
        trim = vehicle.trim
        engine = vehicle.engine
        vin = vehicle.vin
        plate = vehicle.plate
        notes = vehicle.notes
        photoData = try BackupImageSanitizer.sanitizedImageData(from: vehicle.photoData)
        currentMileage = vehicle.currentMileage
    }
}

private extension VehicleRecord {
    var displayName: String {
        let yearText = year > 0 ? String(year) : ""
        let makeText = make?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let modelText = model?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nicknameText = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !nicknameText.isEmpty { return nicknameText }
        let combined = [yearText, makeText, modelText].filter { !$0.isEmpty }.joined(separator: " ")
        return combined.isEmpty ? "Vehicle" : combined
    }
}

private struct ServiceLogRecord: Codable {
    let id: UUID
    let title: String?
    let date: Date
    let mileage: Double
    let cost: Double
    let shop: String?
    let details: String?
    let photoData: Data?

    init(log: ServiceLog) throws {
        id = log.id
        title = log.title
        date = log.date
        mileage = log.mileage
        cost = log.cost
        shop = log.shop
        details = log.details
        photoData = try BackupImageSanitizer.sanitizedImageData(from: log.photoData)
    }
}

private struct ReminderRecord: Codable {
    let id: UUID
    let title: String?
    let details: String?
    let dueDate: Date?
    let dueMileage: Double
    let lastServiceDate: Date?
    let lastServiceMileage: Double
    let repeatIntervalMonths: Int16
    let repeatIntervalMiles: Double
    let isCompleted: Bool
    let linkedServiceLogID: UUID?

    init(reminder: Reminder) {
        id = reminder.id
        title = reminder.title
        details = reminder.details
        dueDate = reminder.dueDate
        dueMileage = reminder.dueMileage
        lastServiceDate = reminder.lastServiceDate
        lastServiceMileage = reminder.lastServiceMileage
        repeatIntervalMonths = reminder.repeatIntervalMonths
        repeatIntervalMiles = reminder.repeatIntervalMiles
        isCompleted = reminder.isCompleted
        linkedServiceLogID = reminder.linkedServiceLogID
    }
}

private struct PartRecord: Codable {
    let id: UUID
    let partName: String?
    let linkedServiceLogID: UUID?
    let date: Date
    let mileage: Double
    let intervalMonths: Int16
    let intervalMiles: Double
    let notes: String?

    init(part: PartReplacement) {
        id = part.id
        partName = part.partName
        linkedServiceLogID = part.linkedServiceLogID
        date = part.date
        mileage = part.mileage
        intervalMonths = part.intervalMonths
        intervalMiles = part.intervalMiles
        notes = part.notes
    }
}

private enum BackupImageSanitizer {
    private static let maxDimension: CGFloat = 1600
    private static let compressionQuality: CGFloat = 0.75
    private static let maxBytes = 5 * 1024 * 1024

    static func sanitizedImageData(from data: Data?) throws -> Data? {
        guard let data else { return nil }
        if data.count <= maxBytes, UIImage(data: data) == nil {
            return data
        }
        guard let image = UIImage(data: data) else {
            throw VehicleBackupError.corruptPhotos
        }

        let resized = resizedImage(from: image)
        guard let jpegData = resized.jpegData(compressionQuality: compressionQuality), jpegData.count <= maxBytes else {
            throw VehicleBackupError.fileTooLarge
        }
        return jpegData
    }

    private static func resizedImage(from image: UIImage) -> UIImage {
        let size = image.size
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension else { return image }
        let scale = maxDimension / largestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
