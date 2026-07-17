import Foundation
import Combine
import CoreData
import WidgetKit

final class LoggingViewModel: ObservableObject {
    @Published var todayCount: Int = 0
    @Published var notes: String = ""
    @Published var hasLoggedToday: Bool = false

    @Published private(set) var todayLog: SmokingLog?

    func load(from logs: [SmokingLog]) {
        let today = Calendar.current.startOfDay(for: Date())
        todayLog = logs.first { $0.date == today }
        if let log = todayLog {
            todayCount = Int(log.count)
            notes = log.notes ?? ""
            hasLoggedToday = true
        } else {
            todayCount = 0
            notes = ""
            hasLoggedToday = false
        }
    }

    func baseline(from profiles: [UserProfile]) -> Int {
        Int(profiles.first?.cigarettesPerDayBefore ?? Int32(0))
    }

    func yesterdayCount(from logs: [SmokingLog]) -> Int? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1,
                                              to: Calendar.current.startOfDay(for: Date()))!
        return logs.first { ($0.date ?? Date()) == yesterday }.map { Int($0.count) }
    }

    func save(context: NSManagedObjectContext, profile: UserProfile?) {
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = todayLog {
            existing.count = Int32(todayCount)
            existing.notes = notes.isEmpty ? nil : notes
            if existing.baselineAtTime == 0, let p = profile {
                existing.baselineAtTime = p.cigarettesPerDayBefore
                existing.pricePerPackAtTime = p.pricePerPack
                existing.cigarettesPerPackAtTime = p.cigarettesPerPack
            }
        } else {
            let log = SmokingLog(context: context, date: today, count: todayCount, notes: notes.isEmpty ? nil : notes)
            if let p = profile {
                log.baselineAtTime = p.cigarettesPerDayBefore
                log.pricePerPackAtTime = p.pricePerPack
                log.cigarettesPerPackAtTime = p.cigarettesPerPack
            }
            todayLog = log
        }
        hasLoggedToday = true
        try? context.save()
    }

    /// 保存今日记录并执行后续副作用：评估成就、重排提醒、刷新小组件，返回激励文案。
    func saveAndProcess(
        context: NSManagedObjectContext,
        profile: UserProfile?,
        logs: [SmokingLog],
        purchases: [PurchaseRecord],
        baseline: Int,
        yesterdayCount: Int?
    ) -> String? {
        save(context: context, profile: profile)

        if let profile = profile {
            var allLogs = logs
            if let today = todayLog, !allLogs.contains(where: { $0.objectID == today.objectID }) {
                allLogs.append(today)
            }
            AchievementService.evaluateAndAward(
                profile: profile, logs: allLogs, purchases: purchases, context: context)
        }

        NotificationService.shared.cancelTodayReminderAndRescheduleTomorrow()
        WidgetCenter.shared.reloadAllTimelines()

        return feedbackMessage(baseline: baseline, yesterdayCount: yesterdayCount)
    }

    /// 最近 30 天的记录（不含今天的空记录）
    func recentLogs(from logs: [SmokingLog]) -> [SmokingLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return logs
            .filter { ($0.date ?? .distantPast) >= Calendar.current.startOfDay(for: cutoff) }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    /// 删除指定的历史记录
    func deleteLogs(_ logsToDelete: [SmokingLog], context: NSManagedObjectContext) {
        for log in logsToDelete {
            context.delete(log)
        }
        try? context.save()
    }

    /// 更新指定历史记录。日期和价格快照保持不变。
    func updateLog(_ log: SmokingLog, count: Int, notes: String, context: NSManagedObjectContext) {
        log.count = Int32(count)
        log.notes = notes.isEmpty ? nil : notes
        try? context.save()
    }

    // MARK: - 保存后正向反馈

    /// 生成保存后的激励消息。baseline = cigarettesPerDayBefore，yesterdayCount 为 nil 表示昨天无记录。
    func feedbackMessage(baseline: Int, yesterdayCount: Int?) -> String? {
        guard hasLoggedToday else { return nil }
        if todayCount == 0 { return "今天完全无烟！继续保持！" }
        if let yesterday = yesterdayCount, todayCount < yesterday {
            return "比昨天少了 \(yesterday - todayCount) 支，继续加油！"
        }
        if baseline > 0 {
            let diff = baseline - todayCount
            if diff > 0 {
                let pct = Int(Double(diff) / Double(baseline) * 100)
                return "比基准少了 \(diff) 支（减少 \(pct)%），不错！"
            } else if diff == 0 {
                return "继续努力，明天再少一支！"
            } else {
                return "今天多了一点，明天可以更好！"
            }
        }
        return "已记录，继续加油！"
    }
}
