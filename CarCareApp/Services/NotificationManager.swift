import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    func scheduleNotification(for reminder: Reminder, vehicleName: String) {
        guard let dueDate = reminder.dueDate, dueDate > Date() else { return }
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = reminder.title ?? "Service Reminder"
        if reminder.dueMileage > 0 {
            content.body = "\(vehicleName): due on \(Self.dateFormatter.string(from: dueDate)) or at \(Formatters.mileageLabel(reminder.dueMileage)) mi"
        } else {
            content.body = "\(vehicleName): due on \(Self.dateFormatter.string(from: dueDate))"
        }
        content.sound = .default

        let notificationDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: dueDate) ?? dueDate
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = reminder.notificationID ?? UUID().uuidString
        reminder.notificationID = identifier

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(request)
    }

    func removeNotification(for reminder: Reminder) {
        guard let identifier = reminder.notificationID else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}
