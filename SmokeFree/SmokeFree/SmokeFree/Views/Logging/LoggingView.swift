import SwiftUI
import CoreData

struct LoggingView: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\SmokingLog.date, order: .reverse)]) private var logs: FetchedResults<SmokingLog>
    @FetchRequest(sortDescriptors: [SortDescriptor(\PurchaseRecord.date, order: .reverse)]) private var purchases: FetchedResults<PurchaseRecord>
    @FetchRequest(sortDescriptors: []) private var profiles: FetchedResults<UserProfile>
    @Environment(\.managedObjectContext) private var context
    @StateObject private var vm = LoggingViewModel()
    @State private var feedbackText: String? = nil
    @State private var editingLog: SmokingLog?

    var body: some View {
        NavigationView {
            List {
                // 今日记录区
                Section("今天") {
                    DailyLogEntryView(vm: vm, feedbackText: feedbackText, onSave: {
                        withAnimation {
                            feedbackText = vm.saveAndProcess(
                                context: context,
                                profile: profiles.first,
                                logs: Array(logs),
                                purchases: Array(purchases),
                                baseline: vm.baseline(from: Array(profiles)),
                                yesterdayCount: vm.yesterdayCount(from: Array(logs))
                            )
                        }
                    })
                }

                // 历史记录
                let recent = vm.recentLogs(from: Array(logs))
                if !recent.isEmpty {
                    Section("最近 30 天") {
                        ForEach(recent, id: \.objectID) { log in
                            Button {
                                editingLog = log
                            } label: {
                                LogRowView(log: log)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { indexSet in
                            vm.deleteLogs(indexSet.map { recent[$0] }, context: context)
                        }
                    }
                }
            }
            .navigationTitle("记录")
            .onAppear { vm.load(from: Array(logs)) }
            .onChange(of: SmokingLog.changeToken(for: logs)) { _ in vm.load(from: Array(logs)) }
            .sheet(isPresented: Binding(
                get: { editingLog != nil },
                set: { isPresented in
                    if !isPresented { editingLog = nil }
                }
            )) {
                if let log = editingLog {
                    EditSmokingLogView(log: log) { count, notes in
                        vm.updateLog(log, count: count, notes: notes, context: context)
                        editingLog = nil
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - 今日记录输入

private struct DailyLogEntryView: View {
    @ObservedObject var vm: LoggingViewModel
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

            TextField("备注（可选）", text: $vm.notes)
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
    @ObservedObject var log: SmokingLog

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

// MARK: - 历史记录编辑

private struct EditSmokingLogView: View {
    @ObservedObject var log: SmokingLog
    let onSave: (Int, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var count: Int
    @State private var notes: String

    init(log: SmokingLog, onSave: @escaping (Int, String) -> Void) {
        self.log = log
        self.onSave = onSave
        _count = State(initialValue: Int(log.count))
        _notes = State(initialValue: log.notes ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section("日期") {
                    Text(log.date ?? Date(), style: .date)
                        .foregroundStyle(.secondary)
                }

                Section("记录") {
                    Stepper(
                        "吸烟 \(count) 支",
                        value: $count,
                        in: 0...200
                    )

                    TextField("备注（可选）", text: $notes)
                }
            }
            .navigationTitle("编辑吸烟记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(count, notes)
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
