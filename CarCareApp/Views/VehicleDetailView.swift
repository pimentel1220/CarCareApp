import SwiftUI

private enum VehicleDetailTab: Hashable {
    case info
    case maintenance
    case reminders
    case parts
}

struct VehicleDetailView: View {
    @ObservedObject var vehicle: Vehicle
    @State private var selectedTab: VehicleDetailTab = .info

    var body: some View {
        TabView(selection: $selectedTab) {
            VehicleInfoView(vehicle: vehicle)
                .tag(VehicleDetailTab.info)
                .tabItem {
                    Label("Info", systemImage: "info.circle")
                }

            MaintenanceLogView(
                vehicle: vehicle,
                onOpenParts: { selectedTab = .parts },
                onOpenReminders: { selectedTab = .reminders }
            )
                .tag(VehicleDetailTab.maintenance)
                .tabItem {
                    Label("Maintenance", systemImage: "wrench")
                }

            RemindersView(vehicle: vehicle)
                .tag(VehicleDetailTab.reminders)
                .tabItem {
                    Label("Reminders", systemImage: "bell")
                }

            PartsView(vehicle: vehicle)
                .tag(VehicleDetailTab.parts)
                .tabItem {
                    Label("Parts", systemImage: "gearshape")
                }
        }
        .navigationTitle(vehicle.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
