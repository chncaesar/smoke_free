import WidgetKit
import SwiftUI

// MARK: - Widget 入口
// 注意：此文件属于独立的 Widget Extension Target，不属于主 App Target。
// 在 Xcode 中需：File → New → Target → Widget Extension，然后将本文件加入该 Target。

struct SmokeFreeWidget: Widget {
    let kind = "SmokeFreeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetProvider()) { entry in
            SmokeFreeWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("控烟进度")
        .description("显示控烟天数和节省金额。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - 入口视图（根据尺寸路由）

struct SmokeFreeWidgetEntryView: View {
    let entry: SmokeFreeEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

// MARK: - 小尺寸（无烟天数）

private struct SmallWidgetView: View {
    let entry: SmokeFreeEntry

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.title)
                .foregroundStyle(.orange)
            Text("\(entry.streakDays)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("天控烟")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 中尺寸（天数 + 节省金额 + 下个里程碑）

private struct MediumWidgetView: View {
    let entry: SmokeFreeEntry

    private var formattedMoney: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = entry.currencyCode
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: entry.moneySaved)) ?? "¥0"
    }

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Label("控烟", systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("\(entry.streakDays) 天")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                if let name = entry.nextMilestoneName {
                    Text("距 \(name) 里程碑")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Label("已省", systemImage: "banknote.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text(formattedMoney)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }
}
