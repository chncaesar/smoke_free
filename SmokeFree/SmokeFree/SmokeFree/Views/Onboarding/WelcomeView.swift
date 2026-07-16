import SwiftUI

struct WelcomeView: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lungs.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            VStack(spacing: 12) {
                Text("欢迎使用 SmokeFree")
                    .font(.largeTitle.bold())

                Text("记录你的控烟之旅\n每一天都是对自己的承诺")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField("你的名字（可选）", text: $vm.name)
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }
}
