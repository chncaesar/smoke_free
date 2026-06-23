import SwiftUI
import SwiftData

struct LoggingView: View {
    @Query(sort: \SmokingLog.date, order: .reverse) private var logs: [SmokingLog]
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var context
    @State private var vm = LoggingViewModel()
    @State private var feedbackText: String? = nil

    private var baseline: Int { profiles.first?.cigarettesPerDayBefore ?? 0 }
    private var yesterdayLog: SmokingLog? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1,
                                              to: Calendar.current.startOfDay(for: Date()))!
        return logs.first { $0.date == yesterday }
    }

    var body: some View {
        NavigationStack {
            List {
                // 今日记录区
                Section("今天") {
                    DailyLogEntryView(vm: vm, feedbackText: feedbackText, onSave: {
                        vm.save(context: context, profile: profiles.first)
                        if let profile = profiles.first {
                            var allLogs = logs.map { $0 }
                            if let today = vm.todayLog, !allLogs.contains(where: { $0.id == today.id }) {
                                allLogs.append(today)
                            }
                            AchievementService.evaluateAndAward(
                                profile: profile, logs: allLogs, context: context)
                        }
                        withAnimation {
                            feedbackText = vm.feedbackMessage(
                                baseline: baseline,
                                yesterdayCount: yesterdayLog?.count
                            )
                        }
                    })
                }

                // 历史记录
                let recent = vm.recentLogs(from: logs)
                if !recent.isEmpty {
                    Section("最近 30 天") {
                        ForEach(recent) { log in
                            LogRowView(log: log)
                        }
                        .onDelete { indexSet in
                            for i in indexSet {
                                context.delete(recent[i])
                            }
                        }
                    }
                }
            }
            .navigationTitle("记录")
            .onAppear { vm.load(from: logs) }
            .onChange(of: logs) { vm.load(from: logs) }
        }
    }
}

// MARK: - 今日记录输入

private struct DailyLogEntryView: View {
    let vm: LoggingViewModel
    let feedbackText: String?
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("今天吸了几支？")
                    .font(.headline)
                Spacer()
                Stepper(
                    "\(vm.todayCount) 支",
                    value: Binding(
                        get: { vm.todayCount },
                        set: { vm.todayCount = $0 }
                    ),
                    in: 0...200
                )
            }

            if vm.todayCount == 0 {
                Label("今天无烟！", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            TextField("备注（可选）", text: Binding(
                get: { vm.notes },
                set: { vm.notes = $0 }
            ))
            .textFieldStyle(.roundedBorder)

            Button(action: onSave) {
                Text(vm.hasLoggedToday ? "更新记录" : "保存")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            // 保存后正向反馈 banner
            if let msg = feedbackText {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.pink)
                    Text(msg)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.pink.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 历史行

private struct LogRowView: View {
    let log: SmokingLog

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.date, style: .date)
                    .font(.subheadline)
                if let notes = log.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 4) {
                if log.count == 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("\(log.count)")
                        .font(.headline.monospacedDigit())
                    Text("支")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
