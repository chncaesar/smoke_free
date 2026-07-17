import SwiftUI

struct QuitDateView: View {
    // Regression coverage: OnboardingViewTests.
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("开始控烟日期")
                    .font(.largeTitle.bold())
                Text("从什么时候开始控烟的？")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)

            DatePicker(
                "控烟开始日期",
                selection: Binding(
                    get: { vm.quitDate },
                    set: { vm.quitDate = $0 }
                ),
                in: ...Date(),
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .tint(.green)
            .padding(.horizontal)

            // 今天快捷按钮
            Button {
                vm.quitDate = Date()
            } label: {
                Label("就是今天", systemImage: "calendar.badge.checkmark")
            }
            .buttonStyle(.bordered)
            .tint(.green)

            Spacer()
        }
    }
}
