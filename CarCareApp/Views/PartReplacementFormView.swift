import SwiftUI
import CoreData
import LinkPresentation

struct PartReplacementFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var vehicle: Vehicle
    var existingPart: PartReplacement?
    var initialPartName: String? = nil

    @State private var partName = ""
    @State private var date = Date()
    @State private var mileage = ""
    @State private var intervalMonths = ""
    @State private var intervalMiles = ""
    @State private var notes = ""
    @State private var sourceURLText = ""
    @State private var selectedServiceLogID: UUID?
    @State private var isFetchingMetadata = false
    @State private var originalMileage: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Part") {
                    TextField("Part Name", text: $partName, axis: .vertical)
                        .lineLimit(1...4)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Mileage", text: $mileage)
                        .keyboardType(.numbersAndPunctuation)

                    HStack {
                        Button("Use Current Mileage") {
                            mileage = Formatters.mileageText(vehicle.latestKnownMileage)
                        }
                        .disabled(vehicle.latestKnownMileage <= 0)

                        Spacer()

                        Button("Use Linked Service") {
                            applyLinkedServiceDefaults(force: true)
                        }
                        .disabled(vehicle.log(with: selectedServiceLogID) == nil)
                    }
                    .font(.caption)
                }

                Section("Reference Link") {
                    TextField("Product/Service URL", text: $sourceURLText, axis: .vertical)
                        .lineLimit(1...4)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled(true)

                    Button(isFetchingMetadata ? "Fetching..." : "Fetch Details") {
                        fetchMetadata()
                    }
                    .disabled(isFetchingMetadata || normalizedURL(from: sourceURLText) == nil)

                    if let sourceURL = normalizedURL(from: sourceURLText) {
                        Link(destination: sourceURL) {
                            Label("Open Link", systemImage: "safari")
                        }
                        .font(.caption)
                    }
                }

                Section("Linked Service") {
                    if vehicle.sortedLogs.isEmpty {
                        Text("No service logs yet. Add a service first, then link it here.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Service", selection: $selectedServiceLogID) {
                            Text("None").tag(Optional<UUID>.none)
                            ForEach(vehicle.sortedLogs) { log in
                                Text(serviceLabel(for: log)).tag(Optional(log.id))
                            }
                        }
                        .pickerStyle(.menu)

                        Button("Use Most Recent Service") {
                            selectedServiceLogID = vehicle.sortedLogs.first?.id
                        }
                    }
                }

                Section("Replacement Interval") {
                    TextField("Months", text: $intervalMonths)
                        .keyboardType(.numberPad)
                    TextField("Miles", text: $intervalMiles)
                        .keyboardType(.numbersAndPunctuation)

                    Button("Use Recommended Interval") {
                        applyRecommendedInterval()
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 120)
                }
            }
            .navigationTitle(existingPart == nil ? "Add Part" : "Edit Part")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if savePart() {
                            dismiss()
                        }
                    }
                }
            }
            .onAppear(perform: loadExistingPart)
            .onChange(of: selectedServiceLogID) { _ in
                guard existingPart == nil else { return }
                applyLinkedServiceDefaults()
            }
        }
    }

    private func loadExistingPart() {
        if let existingPart {
            partName = existingPart.partName ?? ""
            date = existingPart.date
            if existingPart.mileage > 0 {
                mileage = Formatters.mileageText(existingPart.mileage)
            }
            if existingPart.intervalMonths > 0 {
                intervalMonths = String(existingPart.intervalMonths)
            }
            if existingPart.intervalMiles > 0 {
                intervalMiles = Formatters.mileageText(existingPart.intervalMiles)
            }
            notes = existingPart.notes ?? ""
            originalMileage = existingPart.mileage
            sourceURLText = extractStoredURL(from: notes)
            selectedServiceLogID = existingPart.linkedServiceLogID
        } else if vehicle.latestKnownMileage > 0 {
            mileage = Formatters.mileageText(vehicle.latestKnownMileage)
            selectedServiceLogID = vehicle.sortedLogs.first?.id
            if let initialPartName {
                partName = initialPartName
                applyRecommendedInterval()
            }
            applyLinkedServiceDefaults()
        } else if let initialPartName {
            partName = initialPartName
            applyRecommendedInterval()
        }
    }

    @discardableResult
    private func savePart() -> Bool {
        let trimmedName = partName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            AppErrorCenter.shared.message = "Part name is required."
            return false
        }

        let enteredMileage = Formatters.parseMileage(mileage) ?? 0
        guard enteredMileage >= 0 else {
            AppErrorCenter.shared.message = "Mileage cannot be negative."
            return false
        }
        if existingPart != nil {
            if enteredMileage > 0 && enteredMileage < originalMileage {
                AppErrorCenter.shared.message = "Part mileage cannot be lower than the previous value."
                return false
            }
        } else if enteredMileage > 0 && enteredMileage < vehicle.latestKnownMileage {
            AppErrorCenter.shared.message = "Replacement mileage cannot be lower than the current vehicle mileage."
            return false
        }

        let part = existingPart ?? PartReplacement(context: viewContext)
        if existingPart == nil {
            part.id = UUID()
            part.createdAt = Date()
            part.vehicle = vehicle
        }

        part.partName = trimmedName
        part.date = date
        part.mileage = enteredMileage
        part.intervalMonths = Int16(intervalMonths) ?? 0
        part.intervalMiles = Formatters.parseMileage(intervalMiles) ?? 0
        part.linkedServiceLogID = selectedServiceLogID
        part.notes = mergedNotesWithURL(notes: notes, url: sourceURLText)

        if part.mileage > 0 {
            vehicle.currentMileage = max(vehicle.currentMileage, part.mileage)
        }

        do {
            try viewContext.save()
            AppFeedbackCenter.shared.show("Part saved")
            return true
        } catch {
            AppErrorCenter.shared.message = error.localizedDescription
            return false
        }
    }

    private func fetchMetadata() {
        guard let url = normalizedURL(from: sourceURLText) else {
            AppErrorCenter.shared.message = "Enter a valid URL first."
            return
        }
        sourceURLText = url.absoluteString
        isFetchingMetadata = true

        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { metadata, error in
            DispatchQueue.main.async {
                isFetchingMetadata = false
                if let error {
                    AppErrorCenter.shared.message = "Could not fetch details: \(error.localizedDescription)"
                    return
                }

                if let title = metadata?.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !title.isEmpty,
                   partName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    partName = title
                }

                notes = mergedNotesWithURL(notes: notes, url: sourceURLText)
                if intervalMonths.isEmpty && intervalMiles.isEmpty {
                    applyRecommendedInterval()
                }
                AppFeedbackCenter.shared.show("Details fetched")
            }
        }
    }

    private func applyRecommendedInterval() {
        guard let recommendation = PartIntervalRecommendations.recommendation(for: partName) else {
            AppErrorCenter.shared.message = "No recommendation found for this part yet. Enter interval manually."
            return
        }
        intervalMonths = recommendation.intervalMonths > 0 ? String(recommendation.intervalMonths) : ""
        intervalMiles = recommendation.intervalMiles > 0 ? Formatters.mileageText(Double(recommendation.intervalMiles)) : ""
        AppFeedbackCenter.shared.show("Recommended interval applied")
    }

    private func applyLinkedServiceDefaults(force: Bool = false) {
        guard let linkedService = vehicle.log(with: selectedServiceLogID) else { return }

        if force || Formatters.parseMileage(mileage) == nil || (Formatters.parseMileage(mileage) ?? 0) <= 0 {
            if linkedService.mileage > 0 {
                mileage = Formatters.mileageText(linkedService.mileage)
            }
        }

        if force || notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let existingURLNote = extractStoredURL(from: notes)
            let note = "Installed with \(linkedService.title ?? "service") on \(linkedService.date.formatted(date: .abbreviated, time: .omitted))."
            notes = mergedNotesWithURL(notes: note, url: existingURLNote)
        }

        if force {
            date = linkedService.date
        }
    }

    private func serviceLabel(for log: ServiceLog) -> String {
        let name = (log.title ?? "Service").trimmingCharacters(in: .whitespacesAndNewlines)
        let date = log.date.formatted(date: .abbreviated, time: .omitted)
        return "\(name) - \(date)"
    }

    private func normalizedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = URL(string: trimmed), direct.scheme != nil, direct.host != nil {
            return direct
        }
        if let withHTTPS = URL(string: "https://\(trimmed)"), withHTTPS.host != nil {
            return withHTTPS
        }
        return nil
    }

    private func mergedNotesWithURL(notes: String, url: String) -> String {
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized = normalizedURL(from: url)?.absoluteString else {
            return cleanNotes
        }
        let markerPrefix = "Source URL:"
        let lines = cleanNotes
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(markerPrefix) }
        var rebuilt = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if rebuilt.isEmpty {
            rebuilt = "\(markerPrefix) \(normalized)"
        } else {
            rebuilt += "\n\n\(markerPrefix) \(normalized)"
        }
        return rebuilt
    }

    private func extractStoredURL(from notes: String) -> String {
        let markerPrefix = "Source URL:"
        for line in notes.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix(markerPrefix) {
                return trimmed.replacingOccurrences(of: markerPrefix, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }
}
