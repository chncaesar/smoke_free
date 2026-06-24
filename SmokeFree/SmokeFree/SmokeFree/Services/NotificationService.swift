import Foundation
import UserNotifications

struct NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()
    private static let reminderID = "daily_reminder"

    // MARK: - 每日提醒（单次，非重复）

    func scheduleDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderID])
        scheduleReminder(for: Date())
    }

    func cancelTodayReminderAndRescheduleTomorrow() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderID])
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else { return }
        scheduleReminder(for: tomorrow)
    }

    func ensureTodayReminderIfNeeded(hasLoggedToday: Bool) {
        guard !hasLoggedToday else { return }
        center.getPendingNotificationRequests { requests in
            if !requests.contains(where: { $0.identifier == Self.reminderID }) {
                scheduleReminder(for: Date())
            }
        }
    }

    private func scheduleReminder(for date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "记录今天的情况"
        content.body = "别忘了记录今天的烟量，坚持就是胜利！"
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 21
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.reminderID,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - 里程碑通知

    func sendMilestoneNotification(milestone: HealthMilestone) {
        let content = UNMutableNotificationContent()
        content.title = "🎉 控烟里程碑达成！"
        content.body = "\(milestone.title) — \(milestone.description)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "milestone_\(milestone.id)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    // MARK: - 取消

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
