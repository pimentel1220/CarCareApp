import SwiftUI
import CoreData

struct GarageView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Vehicle.createdAt, ascending: true)],
        animation: .default)
    private var vehicles: FetchedResults<Vehicle>

    @State private var showingAddVehicle = false
    @State private var vehiclePendingDeletion: Vehicle?

    var body: some View {
        NavigationStack {
            Group {
                if vehicles.isEmpty {
                    VStack(spacing: 16) {
                        EmptyStateView("Your Garage Is Empty", systemImage: "car", message: "Add your first vehicle to start keeping everything in one place.")
                        Button("Add Vehicle") {
                            showingAddVehicle = true
                        }
                        .buttonStyle(.borderedProminent)
                        Text("You can add mileage, reminders, and service history after setup.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        Section {
                            Text("Choose a vehicle to see what needs attention, log service, and keep your history up to date.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(vehicles) { vehicle in
                            NavigationLink {
                                VehicleDetailView(vehicle: vehicle)
                            } label: {
                                VehicleRowView(vehicle: vehicle)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    vehiclePendingDeletion = vehicle
                                }
                            }
                        }
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
            .alert("Delete Vehicle?", isPresented: vehicleDeleteAlertBinding) {
                Button("Cancel", role: .cancel) {
                    vehiclePendingDeletion = nil
                }
                Button("Delete", role: .destructive) {
                    confirmDeleteVehicle()
                }
            } message: {
                Text("This will remove \(vehiclePendingDeletion?.displayName ?? "this vehicle"), including its services, reminders, and parts.")
            }
        }
    }

    private var vehicleDeleteAlertBinding: Binding<Bool> {
        Binding(
            get: { vehiclePendingDeletion != nil },
            set: { if !$0 { vehiclePendingDeletion = nil } }
        )
    }

    private func confirmDeleteVehicle() {
        guard let vehiclePendingDeletion else { return }
        withAnimation {
            viewContext.delete(vehiclePendingDeletion)
            saveContext(successMessage: "Vehicle removed")
            self.vehiclePendingDeletion = nil
        }
    }

    private func saveContext(successMessage: String) {
        do {
            try viewContext.save()
            AppFeedbackCenter.shared.show(successMessage)
        } catch {
            AppErrorCenter.shared.message = "Could not save changes to your garage right now."
        }
    }
}
