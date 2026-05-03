import Foundation
import HealthKit

/// HealthKit 集成：授权 + 每日写入"无烟正念记录"
///
/// 使用前需在 Xcode → Target → Signing & Capabilities 中添加 HealthKit 能力。
/// 以 mindful session 表示当天无烟状态，在 Health App 中可见。
actor HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    private var mindfulType: HKCategoryType {
        HKObjectType.categoryType(forIdentifier: .mindfulSession)!
    }

    // MARK: - 授权

    /// 请求写入正念记录的权限
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: [mindfulType], read: [])
    }

    // MARK: - 写入今日无烟状态

    /// 将今天标记为无烟日（每天最多写入一次，重复调用安全）
    func recordSmokeFreeToday() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) else { return }

        // 检查今天是否已由本 App 写入过，避免重复
        let timePredicate = HKQuery.predicateForSamples(
            withStart: startOfToday, end: endOfToday, options: .strictStartDate
        )
        let sourcePredicate = HKQuery.predicateForObjects(from: HKSource.default())
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [timePredicate, sourcePredicate])

        let alreadyRecorded: Bool = await withCheckedContinuation { cont in
            let query = HKSampleQuery(
                sampleType: mindfulType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, _ in
                cont.resume(returning: !(samples ?? []).isEmpty)
            }
            store.execute(query)
        }

        guard !alreadyRecorded else { return }

        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: startOfToday,
            end: Date()
        )
        try? await store.save(sample)
    }
}
