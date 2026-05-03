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

    /// 根据控烟开始日期，为所有尚未解锁的里程碑安排一次性推送
    func scheduleMilestoneNotifications(quitDate: Date) {
        // 先清除旧的里程碑通知
        let oldIDs = AppConfig.healthMilestones.map { "milestone_\($0.id)" }
        center.removePendingNotificationRequests(withIdentifiers: oldIDs)

        let now = Date()
        for milestone in AppConfig.healthMilestones {
            let unlockDate = quitDate.addingTimeInterval(milestone.offsetSeconds)
            guard unlockDate > now else { continue } // 已解锁，跳过

            let content = UNMutableNotificationContent()
            content.title = "🎉 健康里程碑解锁！"
            content.body = "控烟里程碑：\(milestone.title) — \(milestone.description)"
            content.sound = .default

            let interval = unlockDate.timeIntervalSince(now)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(
                identifier: "milestone_\(milestone.id)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    // MARK: - 取消

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
