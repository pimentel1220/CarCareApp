import SwiftUI
import CoreData

@main
struct CarCareAppApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var errorCenter = AppErrorCenter.shared
    @StateObject private var feedbackCenter = AppFeedbackCenter.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(errorCenter)
                .environmentObject(feedbackCenter)
        }
    }
}
