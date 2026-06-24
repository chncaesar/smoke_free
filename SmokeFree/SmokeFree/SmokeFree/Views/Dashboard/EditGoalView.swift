import SwiftUI
import CoreData

struct EditGoalView: View {
    let profile: UserProfile
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPresetID: String = ""
    @State private var isCustomMode: Bool = false
    @State private var customName: String = ""
    @State private var customAmount: Double = 0

    init(profile: UserProfile, onSave: @escaping () -> Void) {
        self.profile = profile
        self.onSave = onSave
        if let match = AppConfig.costComparisonPresets.first(where: {
            $0.name == profile.goalName && $0.amount == profile.goalAmount
        }) {
            _selectedPresetID = State(initialValue: match.id)
        } else {
            _isCustomMode = State(initialValue: true)
            _customName = State(initialValue: profile.goalName ?? "")
            _customAmount = State(initialValue: profile.goalAmount)
        }
    }

    private var isValid: Bool {
        if isCustomMode {
            return !customName.trimmingCharacters(in: .whitespaces).isEmpty && customAmount > 0
        }
        return !selectedPresetID.isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section("选择对比目标") {
                    ForEach(AppConfig.costComparisonPresets) { preset in
                        HStack {
                            Image(systemName: preset.iconName)
                                .frame(width: 24)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                Text(formatCurrency(preset.amount))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedPresetID == preset.id && !isCustomMode {
                                Image(systemName: "checkmark").foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPresetID = preset.id
                            isCustomMode = false
                        }
                    }
                }
                Section {
                    Toggle("自定义目标", isOn: $isCustomMode)
                        .onChange(of: isCustomMode, perform: { newVal in
                            if newVal { selectedPresetID = "" }
                        })
                    if isCustomMode {
                        TextField("目标名称", text: $customName)
                        HStack {
                            Text("金额")
                            Spacer()
                            TextField("300000", value: $customAmount, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                            Text(currencySymbol)
                        }
                    }
                } footer: {
                    Text("修改后，卡片将更新为新目标的对比数据。")
                }
            }
            .navigationTitle("更换对比目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        applyChanges()
                        onSave()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func applyChanges() {
        if isCustomMode {
            profile.goalName = customName.trimmingCharacters(in: .whitespaces)
            profile.goalAmount = customAmount
        } else if let preset = AppConfig.costComparisonPresets.first(where: { $0.id == selectedPresetID }) {
            profile.goalName = preset.name
            profile.goalAmount = preset.amount
        }
        try? profile.managedObjectContext?.save()
    }

    private var currencySymbol: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = profile.currencyCode
        return f.currencySymbol ?? profile.currencyCode ?? ""
    }

    private func formatCurrency(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = profile.currencyCode
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: amount)) ?? "¥\(Int(amount))"
    }
}
