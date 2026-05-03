import Foundation
import SwiftData

@Observable
final class ChartsViewModel {
    enum Window: String, CaseIterable {
        case week = "近 7 天"
        case month = "近 30 天"
    }

    var selectedWindow: Window = .week

    struct DayPoint: Identifiable {
        let id = UUID()
        let date: Date
        let count: Int
    }

    struct SpendPoint: Identifiable {
        let id = UUID()
        let date: Date
        let amount: Double
    }

    private(set) var cigaretteData: [DayPoint] = []
    private(set) var spendData: [SpendPoint] = []
    private(set) var avgCigarettes: Double = 0
    private(set) var baselineDailyCount: Int = 0

    func load(logs: [SmokingLog], purchases: [PurchaseRecord], baseline: Int = 0) {
        baselineDailyCount = baseline
        let days = selectedWindow == .week ? 7 : 30
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // 生成过去 N 天的日期序列
        let dates = (0..<days).compactMap {
            cal.date(byAdding: .day, value: -($0), to: today)
        }.reversed()

        // 吸烟量图表
        let logByDate = Dictionary(uniqueKeysWithValues: logs.map { ($0.date, $0.count) })
        cigaretteData = dates.map { d in
            DayPoint(date: d, count: logByDate[d] ?? 0)
        }
        let recordedDays = cigaretteData.filter { logByDate[$0.date] != nil }
        avgCigarettes = recordedDays.isEmpty ? 0 :
            Double(recordedDays.map(\.count).reduce(0, +)) / Double(recordedDays.count)

        // 支出图表：按天聚合购烟花费
        let cutoff = cal.date(byAdding: .day, value: -days, to: today) ?? today
        let filteredPurchases = purchases.filter { $0.date >= cutoff }
        var spendByDate: [Date: Double] = [:]
        for p in filteredPurchases {
            let d = cal.startOfDay(for: p.date)
            spendByDate[d, default: 0] += p.totalCost
        }
        spendData = dates.map { d in
            SpendPoint(date: d, amount: spendByDate[d] ?? 0)
        }
    }
}
