import Testing
@testable import SmokeFree

struct DashboardViewTests {

    @Test func dashboardViewCanBeConstructed() {
        let view = DashboardView()

        #expect(String(describing: type(of: view)) == "DashboardView")
    }
}
