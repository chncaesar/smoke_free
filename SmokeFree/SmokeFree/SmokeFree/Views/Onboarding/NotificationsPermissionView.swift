import SwiftUI
import UserNotifications

struct NotificationsPermissionView: View {
    let vm: OnboardingViewModel
    let onFinish: () -> Void

    @State private var permissionGranted = false
    @State private var permissionDenied = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            VStack(spacing: 12) {
                Text("开启每日提醒")
                    .font(.largeTitle.bold())
                Text("每天提醒你记录烟量\n在关键里程碑时为你庆祝")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                if permissionGranted {
                    Label("通知已开启", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if permissionDenied {
                    Text("通知权限被拒绝，可在系统设置中手动开启")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Button("开启通知权限") {
                        requestNotificationPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }

            Spacer()

            Button("开始我的控烟之旅") {
                onFinish()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                permissionGranted = granted
                permissionDenied = !granted
                if granted {
                    NotificationService.shared.scheduleDailyReminder()
                }
            }
        }
    }
}
