import Foundation
import Combine
import CoreData

final class ChartsViewModel: ObservableObject {
    enum Window: String, CaseIterable {
        case week = "近 7 天"
        case month = "近 30 天"
    }

    @Published var selectedWindow: Window = .week

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

    @Published private(set) var cigaretteData: [DayPoint] = []
    @Published private(set) var spendData: [SpendPoint] = []
    @Published private(set) var avgCigarettes: Double = 0
    @Published private(set) var baselineDailyCount: Int = 0

    func load(logs: [SmokingLog], purchases: [PurchaseRecord], baseline: Int = 0) {
        baselineDailyCount = baseline
        let days = selectedWindow == .week ? 7 : 30
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let dates = (0..<days).compactMap {
            cal.date(byAdding: .day, value: -($0), to: today)
        }.reversed()

        var logByDate: [Date: Int32] = [:]
        for log in logs {
            guard let d = log.date else { continue }
            logByDate[cal.startOfDay(for: d)] = log.count
        }
        cigaretteData = dates.map { d in
            DayPoint(date: d, count: Int(logByDate[d] ?? 0))
        }
        let recordedDays = cigaretteData.filter { logByDate[$0.date] != nil }
        avgCigarettes = recordedDays.isEmpty ? 0 :
            Double(recordedDays.map(\.count).reduce(0, +)) / Double(recordedDays.count)

        let cutoff = cal.date(byAdding: .day, value: -days, to: today) ?? today
        var spendByDate: [Date: Double] = [:]
        for p in purchases {
            guard let pd = p.date else { continue }
            let d = cal.startOfDay(for: pd)
            guard d >= cutoff else { continue }
            spendByDate[d, default: 0] += p.totalCost
        }
        spendData = dates.map { d in
            SpendPoint(date: d, amount: spendByDate[d] ?? 0)
        }
    }
}
