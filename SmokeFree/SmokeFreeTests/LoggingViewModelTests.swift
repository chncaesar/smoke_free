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
}
