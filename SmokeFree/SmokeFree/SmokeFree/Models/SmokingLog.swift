import Foundation
import SwiftData

@Model
final class SmokingLog {
    var id: UUID
    /// 归一化到当天零点
    var date: Date
    var count: Int
    var notes: String?
    var createdAt: Date
    /// 保存时快照的基准用量（nil 表示记录创建时尚未修改过基准，回退到 UserProfile 当前值）
    var baselineAtTime: Int?
    var pricePerPackAtTime: Double?
    var cigarettesPerPackAtTime: Int?

    init(date: Date, count: Int, notes: String? = nil) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.count = count
        self.notes = notes
        self.createdAt = Date()
    }
}
