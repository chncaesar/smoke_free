import Testing
import Foundation
import CoreData
@testable import SmokeFree

struct HealthTimelineViewTests {

    private func makeContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "SmokeFree", managedObjectModel: PersistenceController.model)
        container.persistentStoreDescriptions.first!.type = NSInMemoryStoreType
        container.loadPersistentStores { _, _ in }
        return container.viewContext
    }

    @Test func healthTimelineViewCanBeConstructed() {
        let view = HealthTimelineView()

        #expect(String(describing: type(of: view)) == "HealthTimelineView")
    }

    @Test func timelineDoesNotUnlockFirstMilestoneFromTodayInProgressLog() {
        let context = makeContext()
        let today = Calendar.current.startOfDay(for: Date())
        let profile = UserProfile(
            context: context,
            quitDate: today,
            cigarettesPerDayBefore: 15,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let log = SmokingLog(context: context, date: today, count: 14)
        log.baselineAtTime = 15
        let vm = HealthTimelineViewModel()

        vm.load(profile: profile, logs: [log])

        #expect(vm.items.first?.id == "day1")
        #expect(vm.items.first?.isUnlocked == false)
    }

    @Test func timelineUnlocksFirstMilestoneFromYesterdayBelowBaseline() {
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
        let vm = HealthTimelineViewModel()

        vm.load(profile: profile, logs: [log])

        #expect(vm.items.first?.id == "day1")
        #expect(vm.items.first?.isUnlocked == true)
    }
}
