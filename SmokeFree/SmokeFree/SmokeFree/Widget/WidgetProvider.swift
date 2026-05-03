import WidgetKit
import Foundation

// AppGroup 标识符 — 需与 Xcode Signing & Capabilities 中两个 Target 的配置完全一致
let appGroupID = "group.com.smokefree.app"

// MARK: - Widget 数据键

enum WidgetKey {
    static let streakDays = "widget_streakDays"
    static let moneySaved = "widget_moneySaved"
    static let currencyCode = "widget_currencyCode"
    static let nextMilestoneName = "widget_nextMilestoneName"
}

// MARK: - Timeline Entry

struct SmokeFreeEntry: TimelineEntry {
    let date: Date
    let streakDays: Int
    let moneySaved: Double
    let currencyCode: String
    let nextMilestoneName: String?
}

// MARK: - Timeline Provider

struct WidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> SmokeFreeEntry {
        SmokeFreeEntry(
            date: Date(),
            streakDays: 7,
            moneySaved: 56.0,
            currencyCode: "CNY",
            nextMilestoneName: "1 个月"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SmokeFreeEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SmokeFreeEntry>) -> Void) {
        let entry = readEntry()
        // 每小时刷新一次
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func readEntry() -> SmokeFreeEntry {
        let d = UserDefaults(suiteName: appGroupID)
        return SmokeFreeEntry(
            date: Date(),
            streakDays: d?.integer(forKey: WidgetKey.streakDays) ?? 0,
            moneySaved: d?.double(forKey: WidgetKey.moneySaved) ?? 0,
            currencyCode: d?.string(forKey: WidgetKey.currencyCode) ?? "CNY",
            nextMilestoneName: d?.string(forKey: WidgetKey.nextMilestoneName)
        )
    }
}
