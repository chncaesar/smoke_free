import Foundation
import SwiftData

@Model
final class UnlockedAchievement {
    var id: UUID
    /// 对应 AppConfig.achievementDefinitions 中的 id
    var badgeID: String
    var unlockedAt: Date
    /// 用户查看成就页面后置 false
    var isNewlySeen: Bool

    init(badgeID: String) {
        self.id = UUID()
        self.badgeID = badgeID
        self.unlockedAt = Date()
        self.isNewlySeen = true
    }
}
