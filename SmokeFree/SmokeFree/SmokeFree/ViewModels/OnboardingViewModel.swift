import Foundation
import SwiftData

@Observable
final class OnboardingViewModel {
    var currentStep: Int = 0
    var name: String = ""
    var cigarettesPerDay: Int = 20
    var pricePerPack: Double = 25.0
    var cigarettesPerPack: Int = 20
    var quitDate: Date = Date()

    let totalSteps = 4

    var canProceed: Bool {
        switch currentStep {
        case 0: return true
        case 1: return cigarettesPerDay > 0 && pricePerPack > 0
        case 2: return true
        case 3: return true
        default: return false
        }
    }

    func next() {
        if currentStep < totalSteps - 1 {
            currentStep += 1
        }
    }

    func back() {
        if currentStep > 0 {
            currentStep -= 1
        }
    }

    func finish(context: ModelContext) {
        let profile = UserProfile(
            quitDate: quitDate,
            cigarettesPerDayBefore: cigarettesPerDay,
            pricePerPack: pricePerPack,
            cigarettesPerPack: cigarettesPerPack,
            name: name
        )
        context.insert(profile)
    }
}
