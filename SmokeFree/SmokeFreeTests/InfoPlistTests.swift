import Testing
import Foundation
@testable import SmokeFree

struct InfoPlistTests {

    @Test func appDeclaresRemoteNotificationBackgroundMode() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]

        #expect(modes?.contains("remote-notification") == true)
    }
}
