import SwiftUI

struct AddPurchaseView: View {
    @ObservedObject var vm: PurchaseViewModel
    let onAdd: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("香烟信息") {
                    TextField("品牌名称", text: $vm.newBrand)

                    Stepper(
                        "购买 \(vm.newQuantity) 包",
                        value: Binding(
                            get: { vm.newQuantity },
                            set: { vm.newQuantity = $0 }
                        ),
                        in: 1...100
                    )

                    HStack {
                        Text("单包价格")
                        Spacer()
                        TextField("25", value: Binding(
                            get: { vm.newPricePerPack },
                            set: { vm.newPricePerPack = $0 }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        Text("元")
                    }

                    HStack {
                        Text("合计")
                        Spacer()
                        Text(vm.newTotalCostText)
                            .foregroundStyle(.red)
                    }
                }

                Section("其他") {
                    DatePicker("日期", selection: Binding(
                        get: { vm.newDate },
                        set: { vm.newDate = $0 }
                    ), in: ...Date(), displayedComponents: [.date])

                    TextField("备注（可选）", text: $vm.newNotes)
                }
            }
            .navigationTitle("添加购烟记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") { onAdd() }
                        .disabled(!vm.isFormValid)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
