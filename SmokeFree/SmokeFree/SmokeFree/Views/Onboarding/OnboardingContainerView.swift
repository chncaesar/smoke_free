import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    @State private var vm = OnboardingViewModel()
    @Environment(\.modelContext) private var context
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some View {
        VStack(spacing: 0) {
            // 进度条
            ProgressView(value: Double(vm.currentStep + 1), total: Double(vm.totalSteps))
                .tint(.green)
                .padding(.horizontal)
                .padding(.top, 8)

            // 步骤内容
            Group {
                switch vm.currentStep {
                case 0: WelcomeView(vm: vm)
                case 1: SmokingHabitsView(vm: vm)
                case 2: QuitDateView(vm: vm)
                case 3: NotificationsPermissionView(vm: vm, onFinish: {
                    vm.finish(context: context)
                    NotificationService.shared.scheduleDailyReminder()
                    NotificationService.shared.scheduleMilestoneNotifications(quitDate: vm.quitDate)
                    Task { try? await HealthKitService.shared.requestAuthorization() }
                    onboardingComplete = true
                })
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 导航按钮
            if vm.currentStep < vm.totalSteps - 1 {
                HStack {
                    if vm.currentStep > 0 {
                        Button("返回") { vm.back() }
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("下一步") { vm.next() }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(!vm.canProceed)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}
