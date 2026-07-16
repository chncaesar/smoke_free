import Testing
@testable import SmokeFree

struct HealthTimelineViewTests {

    @Test func healthTimelineViewCanBeConstructed() {
        let view = HealthTimelineView()

        #expect(String(describing: type(of: view)) == "HealthTimelineView")
    }
}
