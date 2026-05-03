import Foundation

@Observable
final class HealthTimelineViewModel {
    struct MilestoneItem: Identifiable {
        let milestone: HealthMilestone
        let isUnlocked: Bool
        let unlockDate: Date
        let timeRemaining: String?

        var id: String { milestone.id }
    }

    private(set) var items: [MilestoneItem] = []

    func load(quitDate: Date) {
        let now = Date()
        let elapsed = now.timeIntervalSince(quitDate)

        items = AppConfig.healthMilestones.map { milestone in
            let unlockDate = quitDate.addingTimeInterval(milestone.offsetSeconds)
            let isUnlocked = elapsed >= milestone.offsetSeconds
            var timeRemaining: String? = nil
            if !isUnlocked {
                let remaining = milestone.offsetSeconds - elapsed
                timeRemaining = formatRemaining(remaining)
            }
            return MilestoneItem(
                milestone: milestone,
                isUnlocked: isUnlocked,
                unlockDate: unlockDate,
                timeRemaining: timeRemaining
            )
        }
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        if s < 3600 {
            return "还需 \(s / 60) 分钟"
        } else if s < 86400 {
            let h = s / 3600
            let m = (s % 3600) / 60
            return m > 0 ? "还需 \(h) 小时 \(m) 分钟" : "还需 \(h) 小时"
        } else {
            let d = s / 86400
            let h = (s % 86400) / 3600
            return h > 0 ? "还需 \(d) 天 \(h) 小时" : "还需 \(d) 天"
        }
    }
}
