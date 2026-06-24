import Foundation
import Combine
import CoreData

final class AchievementsViewModel: ObservableObject {
    struct BadgeItem: Identifiable {
        let definition: AchievementDefinition
        let isUnlocked: Bool
        let unlockedAt: Date?

        var id: String { definition.id }
    }

    @Published private(set) var badges: [BadgeItem] = []
    @Published private(set) var unlockedCount: Int = 0

    func load(unlocked: [UnlockedAchievement]) {
        var unlockedMap: [String: Date] = [:]
        for item in unlocked {
            if let badgeID = item.badgeID, let unlockedAt = item.unlockedAt {
                unlockedMap[badgeID] = unlockedAt
            }
        }
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
