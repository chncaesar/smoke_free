import Testing
import Foundation
import CoreData
@testable import SmokeFree

struct LoggingViewModelTests {

    private func makeContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "SmokeFree", managedObjectModel: PersistenceController.model)
        container.persistentStoreDescriptions.first!.type = NSInMemoryStoreType
        container.loadPersistentStores { _, _ in }
        return container.viewContext
    }

    @Test func updateLogChangesCountAndNotesOnExistingRecord() throws {
        let context = makeContext()
        let log = SmokingLog(context: context, date: Date().addingTimeInterval(-86400), count: 12, notes: "旧备注")
        try context.save()

        let vm = LoggingViewModel()
        vm.updateLog(log, count: 5, notes: "改少了", context: context)

        #expect(log.count == 5)
        #expect(log.notes == "改少了")
    }

    @Test func updateLogStoresEmptyNotesAsNil() throws {
        let context = makeContext()
        let log = SmokingLog(context: context, date: Date().addingTimeInterval(-86400), count: 12, notes: "旧备注")
        try context.save()

        let vm = LoggingViewModel()
        vm.updateLog(log, count: 5, notes: "", context: context)

        #expect(log.count == 5)
        #expect(log.notes == nil)
    }

    @Test func updateLogRecalculatesAchievementsAfterHistoricalEdit() throws {
        let context = makeContext()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let profile = UserProfile(
            context: context,
            quitDate: yesterday,
            cigarettesPerDayBefore: 15,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let log = SmokingLog(context: context, date: yesterday, count: 14)
        log.baselineAtTime = 15
        AchievementService.evaluateAndAward(profile: profile, logs: [log], context: context)

        let vm = LoggingViewModel()
        vm.updateLog(log, count: 15, notes: "", context: context)

        let fetchRequest = NSFetchRequest<UnlockedAchievement>(entityName: "UnlockedAchievement")
        let unlockedIDs = try context.fetch(fetchRequest).compactMap(\.badgeID)
        #expect(!unlockedIDs.contains("streak_1_day"))
    }

    @Test func saveHistoricalLogCreatesMissingDate() throws {
        let context = makeContext()
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: -3, to: Date())!
        let profile = UserProfile(
            context: context,
            quitDate: date,
            cigarettesPerDayBefore: 15,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )

        LoggingViewModel().saveHistoricalLog(
            date: date,
            count: 8,
            notes: "补录",
            context: context,
            profile: profile
        )

        let logs = try context.fetch(SmokingLog.fetchRequest())
        #expect(logs.count == 1)
        #expect(logs.first?.date == cal.startOfDay(for: date))
        #expect(logs.first?.count == 8)
        #expect(logs.first?.notes == "补录")
    }

    @Test func saveHistoricalLogUpdatesExistingDateWithoutDuplicate() throws {
        let context = makeContext()
        let date = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let existing = SmokingLog(context: context, date: date, count: 12, notes: "旧备注")
        try context.save()

        LoggingViewModel().saveHistoricalLog(
            date: date,
            count: 4,
            notes: "新备注",
            context: context,
            profile: nil
        )

        let logs = try context.fetch(SmokingLog.fetchRequest())
        #expect(logs.count == 1)
        #expect(logs.first?.objectID == existing.objectID)
        #expect(logs.first?.count == 4)
        #expect(logs.first?.notes == "新备注")
    }
}
