import SwiftUI
import CoreData
import WidgetKit

struct LoggingView: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\SmokingLog.date, order: .reverse)]) private var logs: FetchedResults<SmokingLog>
    @FetchRequest(sortDescriptors: [SortDescriptor(\PurchaseRecord.date, order: .reverse)]) private var purchases: FetchedResults<PurchaseRecord>
    @FetchRequest(sortDescriptors: []) private var profiles: FetchedResults<UserProfile>
    @Environment(\.managedObjectContext) private var context
    @StateObject private var vm = LoggingViewModel()
    @State private var feedbackText: String? = nil

    private var baseline: Int { Int(profiles.first?.cigarettesPerDayBefore ?? Int32(0)) }
    private var yesterdayLog: SmokingLog? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1,
                                              to: Calendar.current.startOfDay(for: Date()))!
        return logs.first(where: { ($0.date ?? Date()) == yesterday })
    }

    var body: some View {
        NavigationView {
            List {
                // 今日记录区
                Section("今天") {
                    DailyLogEntryView(vm: vm, feedbackText: feedbackText, onSave: {
                        vm.save(context: context, profile: profiles.first)
                        if let profile = profiles.first {
                            var allLogs = logs.map { $0 }
                            if let today = vm.todayLog, !allLogs.contains(where: { $0.objectID == today.objectID }) {
                                allLogs.append(today)
                            }
                            AchievementService.evaluateAndAward(
                                profile: profile, logs: allLogs, purchases: Array(purchases), context: context)
                        }
                        NotificationService.shared.cancelTodayReminderAndRescheduleTomorrow()
                        WidgetCenter.shared.reloadAllTimelines()
                        withAnimation {
                            feedbackText = vm.feedbackMessage(
                                baseline: baseline,
                                yesterdayCount: yesterdayLog.map { Int($0.count) }
                            )
                        }
                    })
                }

                // 历史记录
                let recent = vm.recentLogs(from: Array(logs))
                if !recent.isEmpty {
                    Section("最近 30 天") {
                        ForEach(recent, id: \.objectID) { log in
                            LogRowView(log: log)
                        }
                        .onDelete { indexSet in
                            for i in indexSet {
                                context.delete(recent[i])
                            }
                            try? context.save()
                        }
                    }
                }
            }
            .navigationTitle("记录")
            .onAppear { vm.load(from: Array(logs)) }
            .onChange(of: logs.count) { _ in vm.load(from: Array(logs)) }
        }
        .navigationViewStyle(.stack)
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
                Text(log.date ?? Date(), style: .date)
                    .font(.subheadline)
                if let notes = log.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 4) {
                if Int(log.count) == 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("\(Int(log.count))")
                        .font(.headline.monospacedDigit())
                    Text("支")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
