import Foundation
import SwiftData

struct DataImportService {
    struct ImportResult {
        var profilesUpdated: Int = 0
        var logsAdded: Int = 0
        var logsSkipped: Int = 0
        var purchasesAdded: Int = 0
        var goalsAdded: Int = 0
        var achievementsAdded: Int = 0

        var isEmpty: Bool {
            profilesUpdated == 0 && logsAdded == 0 && purchasesAdded == 0 && goalsAdded == 0 && achievementsAdded == 0
        }
    }

    static func importFromJSON(url: URL, context: ModelContext) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(DataExportService.BackupData.self, from: data)

        var result = ImportResult()

        // UserProfile
        if let pd = backup.userProfile {
            let existing = try context.fetch(FetchDescriptor<UserProfile>())
            if let profile = existing.first {
                profile.quitDate = pd.quitDate
                profile.cigarettesPerDayBefore = pd.cigarettesPerDayBefore
                profile.pricePerPack = pd.pricePerPack
                profile.cigarettesPerPack = pd.cigarettesPerPack
                profile.currencyCode = pd.currencyCode
                profile.name = pd.name
                profile.goalAmount = pd.goalAmount
                profile.goalName = pd.goalName
                result.profilesUpdated = 1
            } else {
                context.insert(UserProfile(
                    quitDate: pd.quitDate,
                    cigarettesPerDayBefore: pd.cigarettesPerDayBefore,
                    pricePerPack: pd.pricePerPack,
                    cigarettesPerPack: pd.cigarettesPerPack,
                    currencyCode: pd.currencyCode,
                    name: pd.name
                ))
                result.profilesUpdated = 1
            }
        }

        // SmokingLog
        let existingLogs = try context.fetch(FetchDescriptor<SmokingLog>())
        var existingLogDates = Set(existingLogs.map { Calendar.current.startOfDay(for: $0.date) })
        let cal = Calendar.current
        for ld in backup.smokingLogs {
            let logDate = cal.startOfDay(for: ld.date)
            guard !existingLogDates.contains(logDate) else {
                result.logsSkipped += 1
                continue
            }
            let log = SmokingLog(date: ld.date, count: ld.count, notes: ld.notes)
            log.baselineAtTime = ld.baselineAtTime
            log.pricePerPackAtTime = ld.pricePerPackAtTime
            log.cigarettesPerPackAtTime = ld.cigarettesPerPackAtTime
            context.insert(log)
            existingLogDates.insert(logDate)
            result.logsAdded += 1
        }

        // PurchaseRecord
        for pd in backup.purchaseRecords {
            let record = PurchaseRecord(date: pd.date, brand: pd.brand, quantity: pd.quantity, pricePerPack: pd.pricePerPack, notes: pd.notes)
            context.insert(record)
            result.purchasesAdded += 1
        }

        // Goal
        for gd in backup.goals {
            let goal = Goal(title: gd.title, reward: gd.reward, targetDays: gd.targetDays, targetMoneySaved: gd.targetMoneySaved)
            goal.isCompleted = gd.isCompleted
            goal.completedAt = gd.completedAt
            context.insert(goal)
            result.goalsAdded += 1
        }

        // UnlockedAchievement
        let existingAchievements = try context.fetch(FetchDescriptor<UnlockedAchievement>())
        var existingBadgeIDs = Set(existingAchievements.map(\.badgeID))
        for ad in backup.unlockedAchievements {
            guard !existingBadgeIDs.contains(ad.badgeID) else { continue }
            let achievement = UnlockedAchievement(badgeID: ad.badgeID)
            achievement.unlockedAt = ad.unlockedAt
            context.insert(achievement)
            existingBadgeIDs.insert(ad.badgeID)
            result.achievementsAdded += 1
        }

        return result
    }
}
