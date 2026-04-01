import SwiftUI
import CoreData

struct GarageView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Vehicle.createdAt, ascending: true)],
        animation: .default)
    private var vehicles: FetchedResults<Vehicle>

    @State private var showingAddVehicle = false

    var body: some View {
        NavigationStack {
            Group {
                if vehicles.isEmpty {
                    VStack(spacing: 16) {
                        EmptyStateView("No Vehicles", systemImage: "car", message: "Add your first vehicle to start tracking maintenance.")
                        Button("Add Vehicle") {
                            showingAddVehicle = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(vehicles) { vehicle in
                            NavigationLink {
                                VehicleDetailView(vehicle: vehicle)
                            } label: {
                                VehicleRowView(vehicle: vehicle)
                            }
                        }
                        .onDelete(perform: deleteVehicles)
                    }
                }
            }
            .navigationTitle("Garage")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddVehicle = true
                    } label: {
                        Label("Add Vehicle", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddVehicle) {
                VehicleFormView()
            }
        }
    }

    private func deleteVehicles(offsets: IndexSet) {
        withAnimation {
            offsets.map { vehicles[$0] }.forEach(viewContext.delete)
            saveContext()
        }
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            AppErrorCenter.shared.message = error.localizedDescription
        }
    }
}
