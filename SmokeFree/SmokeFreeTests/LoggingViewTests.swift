import Testing
@testable import SmokeFree

struct LoggingViewTests {

    @Test func loggingViewCanBeConstructed() {
        let view = LoggingView()

        #expect(String(describing: type(of: view)) == "LoggingView")
    }
}
