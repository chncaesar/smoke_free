import SwiftUI
import SwiftData

struct PurchasesView: View {
    @Query(sort: \PurchaseRecord.date, order: .reverse) private var purchases: [PurchaseRecord]
    @Environment(\.modelContext) private var context
    @State private var vm = PurchaseViewModel()

    var body: some View {
        NavigationStack {
            List {
                // 统计摘要
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("本月支出")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("¥\(String(format: "%.1f", vm.spentThisMonth(purchases: purchases)))")
                                .font(.title2.bold())
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("累计总支出")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("¥\(String(format: "%.1f", vm.totalSpent(purchases: purchases)))")
                                .font(.title2.bold())
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // 按月分组
                let groups = vm.groupedByMonth(purchases: purchases)
                if groups.isEmpty {
                    ContentUnavailableView(
                        "没有购烟记录",
                        systemImage: "cart.badge.minus",
                        description: Text("点击右上角添加记录")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(groups, id: \.0) { (month, records) in
                        Section(month) {
                            ForEach(records) { record in
                                PurchaseRowView(record: record)
                            }
                            .onDelete { indexSet in
                                for i in indexSet { context.delete(records[i]) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("购烟记录")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { vm.showAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $vm.showAddSheet) {
                AddPurchaseView(vm: vm, onAdd: {
                    vm.addPurchase(context: context)
                })
            }
        }
    }
}

// MARK: - 购烟记录行

private struct PurchaseRowView: View {
    let record: PurchaseRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.brand)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(record.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(record.quantity) 包 × ¥\(String(format: "%.1f", record.pricePerPack))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("¥\(String(format: "%.1f", record.totalCost))")
                .font(.headline)
                .foregroundStyle(.red)
        }
    }
}
