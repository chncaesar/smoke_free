import SwiftUI

struct SmokingHabitsView: View {
    let vm: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("控烟前的习惯")
                        .font(.largeTitle.bold())
                    Text("这些数据用于计算你节省了多少钱")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                VStack(alignment: .leading, spacing: 24) {
                    // 每日吸烟量
                    VStack(alignment: .leading, spacing: 8) {
                        Label("每天吸几支？", systemImage: "smoke")
                            .font(.headline)
                        HStack {
                            Stepper(
                                "\(vm.cigarettesPerDay) 支",
                                value: Binding(
                                    get: { vm.cigarettesPerDay },
                                    set: { vm.cigarettesPerDay = $0 }
                                ),
                                in: 1...100
                            )
                        }
                    }

                    Divider()

                    // 每包价格
                    VStack(alignment: .leading, spacing: 8) {
                        Label("每包价格（元）", systemImage: "yensign.circle")
                            .font(.headline)
                        HStack {
                            TextField("25", value: Binding(
                                get: { vm.pricePerPack },
                                set: { vm.pricePerPack = $0 }
                            ), format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            Text("元 / 包")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    // 每包支数
                    VStack(alignment: .leading, spacing: 8) {
                        Label("每包有几支？", systemImage: "number.circle")
                            .font(.headline)
                        Stepper(
                            "\(vm.cigarettesPerPack) 支 / 包",
                            value: Binding(
                                get: { vm.cigarettesPerPack },
                                set: { vm.cigarettesPerPack = $0 }
                            ),
                            in: 10...30,
                            step: 5
                        )
                    }
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Spacer()
            }
        }
    }
}
