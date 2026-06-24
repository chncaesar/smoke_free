import SwiftUI
import CoreData

struct TrendsView: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\SmokingLog.date, order: .reverse)])
    private var logs: FetchedResults<SmokingLog>
    @FetchRequest(sortDescriptors: [SortDescriptor(\PurchaseRecord.date, order: .reverse)])
    private var purchases: FetchedResults<PurchaseRecord>
    @FetchRequest(sortDescriptors: []) private var profiles: FetchedResults<UserProfile>
    @StateObject private var vm = ChartsViewModel()

    private var baseline: Int { Int(profiles.first?.cigarettesPerDayBefore ?? Int32(0)) }

    var body: some View {
        ScrollView {
            if logs.isEmpty && purchases.isEmpty {
                VStack(spacing: 8) {
                    Spacer().frame(height: 40)
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text("还没有记录数据")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("记录每日吸烟量和购烟支出后，这里会显示趋势图表")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            } else {
                VStack(spacing: 20) {
                    Picker("时间范围", selection: Binding(
                        get: { vm.selectedWindow },
                        set: { vm.selectedWindow = $0; reload() }
                    )) {
                        ForEach(ChartsViewModel.Window.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // 吸烟量图表
                    VStack(alignment: .leading, spacing: 8) {
                        Text("每日吸烟量")
                            .font(.headline)
                            .padding(.horizontal)
                        HStack(spacing: 16) {
                            Text("日均 \(String(format: "%.1f", vm.avgCigarettes)) 支")
                                .font(.caption).foregroundStyle(.secondary)
                            if vm.baselineDailyCount > 0 {
                                Text("基准 \(vm.baselineDailyCount) 支")
                                    .font(.caption).foregroundStyle(.secondary)
                                let pct = vm.avgCigarettes < Double(vm.baselineDailyCount)
                                    ? Int((1 - vm.avgCigarettes / Double(vm.baselineDailyCount)) * 100) : 0
                                if pct > 0 {
                                    Text("↓ \(pct)%").font(.caption.bold()).foregroundStyle(.green)
                                }
                            }
                        }
                        .padding(.horizontal)
                        BarChartView(data: vm.cigaretteData.map { ($0.date, Double($0.count), Color.orange) })
                            .frame(height: 180)
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // 支出图表
                    VStack(alignment: .leading, spacing: 8) {
                        Text("购烟支出")
                            .font(.headline)
                            .padding(.horizontal)
                        BarChartView(data: vm.spendData.map { ($0.date, $0.amount, Color.red.opacity(0.7)) })
                            .frame(height: 180)
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("趋势")
        .onAppear { reload() }
        .onChange(of: logs.count) { _ in reload() }
        .onChange(of: purchases.count) { _ in reload() }
    }

    private func reload() {
        vm.load(logs: Array(logs), purchases: Array(purchases), baseline: baseline)
    }
}

// MARK: - 手绘柱状图 (iOS 15 兼容)

private struct BarChartView: View {
    let data: [(date: Date, value: Double, color: Color)]

    private var maxValue: Double { data.map(\.value).max() ?? 1 }

    var body: some View {
        GeometryReader { geo in
            let barWidth = max(4, (geo.size.width / CGFloat(max(1, data.count))) - 4)
            let chartHeight = geo.size.height - 20
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(data.indices, id: \.self) { i in
                    let point = data[i]
                    let barH = maxValue > 0 ? CGFloat(point.value / maxValue) * chartHeight : 0
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(point.color)
                            .frame(width: barWidth, height: max(barH, 1))
                            .cornerRadius(2)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .overlay(alignment: .bottom) {
                // 日期标签
                let step = max(1, data.count / 6)
                HStack(spacing: 2) {
                    ForEach(data.indices, id: \.self) { i in
                        VStack(spacing: 0) {
                            if i % step == 0 || i == data.count - 1 {
                                let df = DateFormatter()
                                let text = Text(df.shortDay(from: data[i].date))
                                    .font(.system(size: 8)).foregroundStyle(.secondary)
                                    .frame(width: barWidth + 2)
                                text
                            } else {
                                Color.clear.frame(width: barWidth + 2, height: 1)
                            }
                        }
                    }
                }
                .offset(y: 16)
            }
        }
    }
}

extension DateFormatter {
    func shortDay(from date: Date) -> String {
        self.dateFormat = "d"
        return self.string(from: date)
    }
}
