import SwiftUI

private enum VehicleDetailTab: Hashable {
    case overview
    case info
    case maintenance
    case reminders
    case parts
}

struct VehicleDetailView: View {
    @ObservedObject var vehicle: Vehicle
    @State private var selectedTab: VehicleDetailTab = .overview
    @State private var editingOverviewLog: ServiceLog?
    @State private var editingOverviewReminder: Reminder?
    @State private var editingOverviewPart: PartReplacement?

    var body: some View {
        TabView(selection: $selectedTab) {
            VehicleOverviewView(
                vehicle: vehicle,
                onOpenInfo: { selectedTab = .info },
                onOpenMaintenance: { selectedTab = .maintenance },
                onOpenReminders: { selectedTab = .reminders },
                onOpenParts: { selectedTab = .parts },
                onOpenService: { editingOverviewLog = $0 },
                onOpenReminder: { editingOverviewReminder = $0 },
                onOpenPart: { editingOverviewPart = $0 }
            )
                .tag(VehicleDetailTab.overview)
                .tabItem {
                    Label("Overview", systemImage: "car.fill")
                }

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
        .sheet(item: $editingOverviewLog) { log in
            ServiceLogFormView(
                vehicle: vehicle,
                existingLog: log,
                onOpenParts: { selectedTab = .parts },
                onOpenReminders: { selectedTab = .reminders }
            )
        }
        .sheet(item: $editingOverviewReminder) { reminder in
            ReminderFormView(vehicle: vehicle, existingReminder: reminder)
        }
        .sheet(item: $editingOverviewPart) { part in
            PartReplacementFormView(vehicle: vehicle, existingPart: part)
        }
    }
}
