import SwiftUI

struct AddGoalView: View {
    @ObservedObject var vm: GoalsViewModel
    let onAdd: () -> Void
    var isEditing: Bool = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("目标") {
                    TextField("例：连续控烟一周", text: $vm.newTitle)
                }

                Section("达成条件") {
                    Stepper(
                        "连续控烟 \(vm.newTargetDays) 天",
                        value: Binding(
                            get: { vm.newTargetDays },
                            set: { vm.newTargetDays = $0 }
                        ),
                        in: 1...365
                    )

                    let moneyToggleDisabled = vm.hasActiveMoneyGoal && (vm.editingGoal?.targetMoneySaved ?? 0) == 0
                    Toggle("同时设置金额目标", isOn: Binding(
                        get: { vm.useMoneyTarget },
                        set: { vm.useMoneyTarget = $0 }
                    ))
                    .disabled(moneyToggleDisabled)
                    if moneyToggleDisabled {
                        Text("已有一个进行中的金额目标")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if vm.useMoneyTarget {
                        HStack {
                            Text("节省金额达到")
                            Spacer()
                            TextField("100", value: Binding(
                                get: { vm.newTargetMoney ?? 0 },
                                set: { vm.newTargetMoney = $0 }
                            ), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            Text("元")
                        }
                    }
                }

                Section("奖励") {
                    TextField("例：买一本新书", text: $vm.newReward)
                }
            }
            .navigationTitle(isEditing ? "编辑目标" : "添加目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "保存" : "添加") {
                        onAdd()
                    }
                    .disabled(!vm.isFormValid)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
