import Testing
import Foundation
@testable import SmokeFree

struct UserProfileTests {

    // MARK: - streakDays

    @Test func streakDays_exactlyOneDayAgo() {
        let quitDate = Date().addingTimeInterval(-86400)
        let profile = UserProfile(
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        #expect(profile.streakDays == 1)
    }

    @Test func streakDays_tenDaysAgo() {
        let quitDate = Date().addingTimeInterval(-86400 * 10)
        let profile = UserProfile(
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        #expect(profile.streakDays == 10)
    }

    @Test func streakDays_futureQuitDate_returnsZero() {
        let quitDate = Date().addingTimeInterval(3600) // 1 小时后
        let profile = UserProfile(
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        #expect(profile.streakDays == 0)
    }

    // MARK: - moneySaved

    @Test func moneySaved_oneDay_correctAmount() {
        // 20 支/天，¥25/包，20 支/包 → 单支 ¥1.25
        // 1 天 = 20 支 × ¥1.25 = ¥25
        let quitDate = Date().addingTimeInterval(-86400)
        let profile = UserProfile(
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        #expect(profile.moneySaved.isApproximatelyEqual(to: 25.0, tolerance: 0.5))
    }

    @Test func moneySaved_tenDays_correctAmount() {
        // 20 支/天 × 10 天 = 200 支，单支 ¥1.25 → ¥250
        let quitDate = Date().addingTimeInterval(-86400 * 10)
        let profile = UserProfile(
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        #expect(profile.moneySaved.isApproximatelyEqual(to: 250.0, tolerance: 1.0))
    }

    @Test func moneySaved_customPackSize() {
        // 10 支/天，¥30/包，10 支/包 → 单支 ¥3.0
        // 1 天 → ¥30
        let quitDate = Date().addingTimeInterval(-86400)
        let profile = UserProfile(
            quitDate: quitDate,
            cigarettesPerDayBefore: 10,
            pricePerPack: 30,
            cigarettesPerPack: 10
        )
        #expect(profile.moneySaved.isApproximatelyEqual(to: 30.0, tolerance: 0.5))
    }
}

// MARK: - 辅助

private extension Double {
    func isApproximatelyEqual(to other: Double, tolerance: Double) -> Bool {
        abs(self - other) <= tolerance
    }
}
