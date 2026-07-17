import Testing
import Foundation
import CoreData
@testable import SmokeFree

struct SmokingLogChangeTokenTests {

    private func makeContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "SmokeFree", managedObjectModel: PersistenceController.model)
        container.persistentStoreDescriptions.first!.type = NSInMemoryStoreType
        container.loadPersistentStores { _, _ in }
        return container.viewContext
    }

    @Test func changeTokenChangesWhenExistingLogCountChanges() {
        let context = makeContext()
        let log = SmokingLog(context: context, date: Date(), count: 15)
        try? context.save()

        let before = SmokingLog.changeToken(for: [log])
        log.count = 16
        try? context.save()
        let after = SmokingLog.changeToken(for: [log])

        #expect(before != after)
    }
}
