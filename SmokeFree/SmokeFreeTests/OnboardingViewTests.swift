import Testing
import SwiftUI
@testable import SmokeFree

struct OnboardingViewTests {
    @Test func smokingHabitsViewObservesViewModel() {
        let mirror = Mirror(reflecting: SmokingHabitsView(vm: OnboardingViewModel()))

        #expect(mirror.children.contains { $0.label == "_vm" })
    }

    @Test func quitDateViewObservesViewModel() {
        let mirror = Mirror(reflecting: QuitDateView(vm: OnboardingViewModel()))

        #expect(mirror.children.contains { $0.label == "_vm" })
    }
}
