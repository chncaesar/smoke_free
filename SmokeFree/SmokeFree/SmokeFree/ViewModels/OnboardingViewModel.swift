import Foundation
import Combine
import CoreData

final class OnboardingViewModel: ObservableObject {
    @Published var currentStep: Int = 0
    @Published var name: String = ""
    @Published var cigarettesPerDay: Int = 20
    @Published var pricePerPack: Double = 25.0
    @Published var cigarettesPerPack: Int = 20
    @Published var quitDate: Date = Date()

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

    func finish(context: NSManagedObjectContext) {
        let profile = UserProfile(
            context: context,
            quitDate: quitDate,
            cigarettesPerDayBefore: cigarettesPerDay,
            pricePerPack: pricePerPack,
            cigarettesPerPack: cigarettesPerPack,
            name: name
        )
        context.insert(profile)
    }
}
