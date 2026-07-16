import Testing
@testable import SmokeFree

struct GoalsViewTests {

    @Test func goalsViewCanBeConstructed() {
        let view = GoalsView()

        #expect(String(describing: type(of: view)) == "GoalsView")
    }
}
