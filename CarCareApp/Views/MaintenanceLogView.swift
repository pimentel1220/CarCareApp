import SwiftUI
import CoreData

struct MaintenanceLogView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var vehicle: Vehicle
    var onOpenParts: (() -> Void)? = nil
    var onOpenReminders: (() -> Void)? = nil

    @State private var showingAddLog = false
    @State private var editingLog: ServiceLog?
    @State private var selectedType = "All"

    var body: some View {
        List {
            if filteredLogs.isEmpty {
                VStack(spacing: 16) {
                    EmptyStateView("No Service Logs", systemImage: "wrench", message: "Tap below to add your first service entry.")
                    Button("Add Service") {
                        showingAddLog = true
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Go to Parts") {
                        onOpenParts?()
                    }
                    Button("Go to Reminders") {
                        onOpenReminders?()
                    }
                }
            } else {
                Section {
                    ForEach(filteredLogs) { log in
                        Button {
                            editingLog = log
                        } label: {
                            ServiceLogRowView(log: log, linkedPartNames: linkedPartNames(for: log))
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .leading) {
                            Button("Parts") {
                                onOpenParts?()
                            }
                            .tint(.orange)
                            Button("Reminders") {
                                onOpenReminders?()
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete(perform: deleteLogs)
                } header: {
                    HStack {
                        Text("Service Logs")
                        Spacer()
                        Button("Add Service") {
                            showingAddLog = true
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle("Maintenance")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Type", selection: $selectedType) {
                        ForEach(filterTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddLog = true
                } label: {
                    Label("Add Service", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddLog) {
            ServiceLogFormView(vehicle: vehicle, onOpenParts: onOpenParts, onOpenReminders: onOpenReminders)
        }
        .sheet(item: $editingLog) { log in
            ServiceLogFormView(vehicle: vehicle, existingLog: log, onOpenParts: onOpenParts, onOpenReminders: onOpenReminders)
        }
    }

    private var filterTypes: [String] {
        let types = Set(vehicle.sortedLogs.compactMap { log in
            let trimmed = (log.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        })
        return ["All"] + types.sorted()
    }

    private var filteredLogs: [ServiceLog] {
        if selectedType == "All" {
            return vehicle.sortedLogs
        }
        return vehicle.sortedLogs.filter { ($0.title ?? "") == selectedType }
    }

    private func deleteLogs(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredLogs[$0] }.forEach(viewContext.delete)
            saveContext(savedMessage: "Service deleted")
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
}

private struct ServiceLogRowView: View {
    let log: ServiceLog
    let linkedPartNames: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(log.title ?? "Service")
                .font(.headline)
            Text(log.date, style: .date)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text("Mileage: \(Formatters.mileageLabel(log.mileage))")
                if log.cost > 0 {
                    Text("Cost: $\(String(format: "%.2f", log.cost))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !linkedPartNames.isEmpty {
                Text("Parts: \(linkedPartNames.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private extension MaintenanceLogView {
    func linkedPartNames(for log: ServiceLog) -> [String] {
        let names = vehicle.sortedParts
            .filter { $0.linkedServiceLogID == log.id }
            .compactMap { part in
                let name = (part.partName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? nil : name
            }
            .map(shortPartLabel)

        if names.count > 2 {
            return Array(names.prefix(2)) + ["+\(names.count - 2) more"]
        }
        return names
    }

    func shortPartLabel(_ name: String) -> String {
        if name.count <= 24 { return name }
        let cutoff = name.index(name.startIndex, offsetBy: 21)
        return String(name[..<cutoff]) + "..."
    }
}
