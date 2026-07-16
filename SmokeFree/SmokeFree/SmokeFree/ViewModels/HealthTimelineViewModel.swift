import Foundation
import Combine

final class HealthTimelineViewModel: ObservableObject {
    struct MilestoneItem: Identifiable {
        let milestone: HealthMilestone
        let isUnlocked: Bool
        let unlockDate: Date?
        let remainingText: String?

        var id: String { milestone.id }
    }

    @Published private(set) var items: [MilestoneItem] = []

    func load(profile: UserProfile, logs: [SmokingLog]) {
        load(streakDays: profile.actualStreakDays(logs: logs), profile: profile)
    }

    func load(streakDays: Int, profile: UserProfile) {
        items = AppConfig.healthMilestones.map { milestone in
            let isUnlocked = streakDays >= milestone.requiredStreakDays
            let unlockDate: Date?
            let remainingText: String?

            if isUnlocked {
                unlockDate = profile.milestoneUnlockDate(
                    streakDays: streakDays,
                    requiredDays: milestone.requiredStreakDays
                )
                remainingText = nil
            } else {
                unlockDate = nil
                let remaining = milestone.requiredStreakDays - streakDays
                remainingText = "还需连续控烟 \(remaining) 天"
            }

            return MilestoneItem(
                milestone: milestone,
                isUnlocked: isUnlocked,
                unlockDate: unlockDate,
                remainingText: remainingText
            )
        }
    }
}
