import SwiftUI
import Charts
import SwiftData

struct TrendsView: View {
    @Query private var logs: [SmokingLog]
    @Query private var purchases: [PurchaseRecord]
    @Query private var profiles: [UserProfile]
    @State private var vm = ChartsViewModel()

    private var baseline: Int { profiles.first?.cigarettesPerDayBefore ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Picker("时间范围", selection: Binding(
                    get: { vm.selectedWindow },
                    set: { vm.selectedWindow = $0; vm.load(logs: logs, purchases: purchases) }
                )) {
                    ForEach(ChartsViewModel.Window.allCases, id: \.self) {
                        Text($0.rawValue)
                    }
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
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if vm.baselineDailyCount > 0 {
                            Text("基准 \(vm.baselineDailyCount) 支")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            let pct = vm.avgCigarettes < Double(vm.baselineDailyCount)
                                ? Int((1 - vm.avgCigarettes / Double(vm.baselineDailyCount)) * 100)
                                : 0
                            if pct > 0 {
                                Text("↓ \(pct)%")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Chart(vm.cigaretteData) { point in
                        BarMark(
                            x: .value("日期", point.date, unit: .day),
                            y: .value("支数", point.count)
                        )
                        .foregroundStyle(.orange)
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: vm.selectedWindow == .week ? 1 : 5)) { _ in
                            AxisValueLabel(format: .dateTime.day())
                        }
                    }
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

                    Chart(vm.spendData) { point in
                        BarMark(
                            x: .value("日期", point.date, unit: .day),
                            y: .value("金额", point.amount)
                        )
                        .foregroundStyle(.red.opacity(0.7))
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: vm.selectedWindow == .week ? 1 : 5)) { _ in
                            AxisValueLabel(format: .dateTime.day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel { Text("¥\(value.as(Double.self).map { Int($0) } ?? 0)") }
                        }
                    }
                    .frame(height: 180)
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("趋势")
        .onAppear { vm.load(logs: logs, purchases: purchases, baseline: baseline) }
        .onChange(of: logs) { vm.load(logs: logs, purchases: purchases, baseline: baseline) }
        .onChange(of: purchases) { vm.load(logs: logs, purchases: purchases, baseline: baseline) }
    }
}
