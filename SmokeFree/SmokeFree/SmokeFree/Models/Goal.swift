import Foundation
import SwiftData

@Model
final class Goal {
    var id: UUID
    var title: String
    var reward: String
    var targetDays: Int
    var targetMoneySaved: Double?
    var isCompleted: Bool
    var completedAt: Date?
    var sortOrder: Int
    var createdAt: Date

    init(
        title: String,
        reward: String,
        targetDays: Int,
        targetMoneySaved: Double? = nil,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.reward = reward
        self.targetDays = targetDays
        self.targetMoneySaved = targetMoneySaved
        self.isCompleted = false
        self.completedAt = nil
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
