import SwiftUI
import CoreData

struct PartsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var vehicle: Vehicle

    @State private var showingAddPart = false
    @State private var editingPart: PartReplacement?
    @State private var draftPartName = "Oil Filter"

    var body: some View {
        List {
            Section("Quick Add") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(quickAddParts, id: \.self) { part in
                            Button(part) {
                                draftPartName = part
                                showingAddPart = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if vehicle.sortedParts.isEmpty {
                VStack(spacing: 16) {
                    EmptyStateView("No Parts", systemImage: "gearshape", message: "Track replaced parts and intervals.")
                    Button("Add Part") {
                        draftPartName = "Oil Filter"
                        showingAddPart = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Section {
                    ForEach(vehicle.sortedParts) { part in
                        Button {
                            editingPart = part
                        } label: {
                            PartRowView(part: part, vehicle: vehicle, currentMileage: vehicle.currentMileage)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteParts)
                } header: {
                    HStack {
                        Text("Parts")
                        Spacer()
                        Button("Add Part") {
                            draftPartName = "Oil Filter"
                            showingAddPart = true
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle("Parts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    draftPartName = "Oil Filter"
                    showingAddPart = true
                } label: {
                    Label("Add Part", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPart) {
            PartReplacementFormView(vehicle: vehicle, initialPartName: draftPartName)
        }
        .sheet(item: $editingPart) { part in
            PartReplacementFormView(vehicle: vehicle, existingPart: part)
        }
    }

    private func deleteParts(offsets: IndexSet) {
        withAnimation {
            offsets.map { vehicle.sortedParts[$0] }.forEach(viewContext.delete)
            saveContext(savedMessage: "Part deleted")
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

    private var quickAddParts: [String] {
        [
            "Oil Filter",
            "Battery",
            "Brake Pads",
            "Engine Air Filter",
            "Cabin Air Filter",
            "Wiper Blades"
        ]
    }
}

private struct PartRowView: View {
    let part: PartReplacement
    let vehicle: Vehicle
    let currentMileage: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(part.partName ?? "Part")
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(part.date, style: .date)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if part.mileage > 0 {
                Text("Replaced at \(Formatters.mileageLabel(part.mileage)) mi")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if currentMileage > 0 && part.mileage > 0 {
                let milesSince = currentMileage - part.mileage
                Text("\(Formatters.mileageLabel(abs(milesSince))) mi since last replacement")
                    .font(.caption)
                    .foregroundColor(milesSince >= 0 ? .secondary : .red)
            }

            if let linked = vehicle.log(with: part.linkedServiceLogID) {
                Text("Linked service: \(linked.title ?? "Service")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}
