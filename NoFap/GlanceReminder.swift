import Foundation
import UserNotifications

enum GlanceNotice {
    static let title = "NoFap"
    static let body = "时间还在往前走。打开就能看到，这不是打卡。"
    static let identifier = "nofap.glance"
}

enum GlanceReminder {
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func apply(enabled: Bool, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [GlanceNotice.identifier])
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = GlanceNotice.title
        content.body = GlanceNotice.body
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: GlanceNotice.identifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }
}
