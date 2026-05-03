import Foundation
import SwiftData

@Observable
final class AchievementsViewModel {
    struct BadgeItem: Identifiable {
        let definition: AchievementDefinition
        let isUnlocked: Bool
        let unlockedAt: Date?

        var id: String { definition.id }
    }

    private(set) var badges: [BadgeItem] = []
    private(set) var unlockedCount: Int = 0

    func load(unlocked: [UnlockedAchievement]) {
        let unlockedMap = Dictionary(uniqueKeysWithValues: unlocked.map { ($0.badgeID, $0.unlockedAt) })
        badges = AppConfig.achievementDefinitions.map { def in
            BadgeItem(
                definition: def,
                isUnlocked: unlockedMap[def.id] != nil,
                unlockedAt: unlockedMap[def.id]
            )
        }
        unlockedCount = unlocked.count

        // 标记已查看
        for item in unlocked where item.isNewlySeen {
            item.isNewlySeen = false
        }
    }
}
