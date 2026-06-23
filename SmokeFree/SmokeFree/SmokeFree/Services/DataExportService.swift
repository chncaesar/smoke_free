import Foundation
import SwiftData

struct DataExportService {
    struct BackupData: Codable {
        let version: Int
        let exportDate: Date
        let userProfile: ProfileData?
        let smokingLogs: [LogData]
        let purchaseRecords: [PurchaseData]
        let goals: [GoalData]
        let unlockedAchievements: [AchievementData]
    }

    struct ProfileData: Codable {
        let quitDate: Date
        let cigarettesPerDayBefore: Int
        let pricePerPack: Double
        let cigarettesPerPack: Int
        let currencyCode: String
        let name: String
        let goalAmount: Double
        let goalName: String
    }

    struct LogData: Codable {
        let date: Date
        let count: Int
        let notes: String?
        let baselineAtTime: Int?
        let pricePerPackAtTime: Double?
        let cigarettesPerPackAtTime: Int?
    }

    struct PurchaseData: Codable {
        let date: Date
        let brand: String
        let quantity: Int
        let pricePerPack: Double
        let totalCost: Double
        let notes: String?
    }

    struct GoalData: Codable {
        let title: String
        let reward: String
        let targetDays: Int
        let targetMoneySaved: Double?
        let isCompleted: Bool
        let completedAt: Date?
    }

    struct AchievementData: Codable {
        let badgeID: String
        let unlockedAt: Date
    }

    static func exportData(context: ModelContext) throws -> URL {
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        let logs = try context.fetch(FetchDescriptor<SmokingLog>())
        let purchases = try context.fetch(FetchDescriptor<PurchaseRecord>())
        let goals = try context.fetch(FetchDescriptor<Goal>())
        let achievements = try context.fetch(FetchDescriptor<UnlockedAchievement>())

        let profileData: ProfileData?
        if let p = profiles.first {
            profileData = ProfileData(
                quitDate: p.quitDate, cigarettesPerDayBefore: p.cigarettesPerDayBefore,
                pricePerPack: p.pricePerPack, cigarettesPerPack: p.cigarettesPerPack,
                currencyCode: p.currencyCode, name: p.name,
                goalAmount: p.goalAmount, goalName: p.goalName
            )
        } else {
            profileData = nil
        }

        let backup = BackupData(
            version: 1,
            exportDate: Date(),
            userProfile: profileData,
            smokingLogs: logs.map { LogData(date: $0.date, count: $0.count, notes: $0.notes, baselineAtTime: $0.baselineAtTime, pricePerPackAtTime: $0.pricePerPackAtTime, cigarettesPerPackAtTime: $0.cigarettesPerPackAtTime) },
            purchaseRecords: purchases.map { PurchaseData(date: $0.date, brand: $0.brand, quantity: $0.quantity, pricePerPack: $0.pricePerPack, totalCost: $0.totalCost, notes: $0.notes) },
            goals: goals.map { GoalData(title: $0.title, reward: $0.reward, targetDays: $0.targetDays, targetMoneySaved: $0.targetMoneySaved, isCompleted: $0.isCompleted, completedAt: $0.completedAt) },
            unlockedAchievements: achievements.map { AchievementData(badgeID: $0.badgeID, unlockedAt: $0.unlockedAt) }
        )

        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        let dateStr = df.string(from: Date())
        let dirName = "smoke_free_backup_\(dateStr)"
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(dirName)
        try? FileManager.default.removeItem(at: tmpDir)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        // JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(backup)
        try jsonData.write(to: tmpDir.appendingPathComponent("data.json"))

        // CSV files
        var csv = ""
        if let p = profileData {
            csv = "戒烟日期,每日基准(支),每包价格,每包支数,货币,姓名,梦想目标名,梦想金额\n"
            csv += csvLine(dfISO.string(from: p.quitDate), "\(p.cigarettesPerDayBefore)", "\(p.pricePerPack)", "\(p.cigarettesPerPack)", p.currencyCode, p.name, p.goalName, "\(p.goalAmount)")
            try Data(csv.utf8).write(to: tmpDir.appendingPathComponent("用户档案.csv"))
        }

        csv = "日期,支数,备注,记录时基准,记录时每包价格,记录时每包支数\n"
        for l in backup.smokingLogs.sorted(by: { $0.date < $1.date }) {
            csv += csvLine(dfISO.string(from: l.date), "\(l.count)", esc(l.notes), opt(l.baselineAtTime), opt(l.pricePerPackAtTime), opt(l.cigarettesPerPackAtTime))
        }
        try Data(csv.utf8).write(to: tmpDir.appendingPathComponent("吸烟记录.csv"))

        csv = "日期,品牌,包数,每包价格,总价,备注\n"
        for p in backup.purchaseRecords.sorted(by: { $0.date < $1.date }) {
            csv += csvLine(dfISO.string(from: p.date), p.brand, "\(p.quantity)", "\(p.pricePerPack)", "\(p.totalCost)", esc(p.notes))
        }
        try Data(csv.utf8).write(to: tmpDir.appendingPathComponent("购烟记录.csv"))

        csv = "标题,奖励,目标天数,目标金额,是否完成,完成日期\n"
        for g in backup.goals {
            csv += csvLine(g.title, g.reward, "\(g.targetDays)", opt(g.targetMoneySaved), g.isCompleted ? "是" : "否", g.completedAt.map { dfISO.string(from: $0) } ?? "")
        }
        try Data(csv.utf8).write(to: tmpDir.appendingPathComponent("目标.csv"))

        csv = "徽章ID,解锁日期\n"
        for a in backup.unlockedAchievements {
            csv += csvLine(a.badgeID, dfISO.string(from: a.unlockedAt))
        }
        try Data(csv.utf8).write(to: tmpDir.appendingPathComponent("成就.csv"))

        return tmpDir
    }

    private static let dfISO: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        return f
    }()

    private static func csvLine(_ values: String...) -> String {
        values.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",") + "\n"
    }

    private static func esc(_ s: String?) -> String { s ?? "" }
    private static func opt(_ v: (any CustomStringConvertible)?) -> String { v?.description ?? "" }
}
