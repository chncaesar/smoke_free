import Foundation
import UserNotifications

/// 通知服务：每日提醒 + 健康里程碑庆祝推送
struct NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    // MARK: - 每日提醒

    /// 安排每天 21:00 的记录提醒（重复触发）
    func scheduleDailyReminder() {
        let content = UNMutableNotificationContent()
        content.title = "记录今天的情况"
        content.body = "别忘了记录今天的烟量，坚持就是胜利！"
        content.sound = .default

        var components = DateComponents()
        components.hour = 21
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily_reminder",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - 里程碑通知

    /// 里程碑达成时即时推送庆祝通知
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
