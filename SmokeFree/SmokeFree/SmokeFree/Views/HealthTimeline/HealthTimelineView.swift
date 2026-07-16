import SwiftUI
import CoreData

struct HealthTimelineView: View {
    @FetchRequest(sortDescriptors: []) private var profiles: FetchedResults<UserProfile>
    @FetchRequest(sortDescriptors: [SortDescriptor(\SmokingLog.date, order: .reverse)]) private var logs: FetchedResults<SmokingLog>
    @StateObject private var vm = HealthTimelineViewModel()

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image("SmokingLung")
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("长期吸烟导致肺部变黑、功能受损。\n停止吸烟后，肺部会逐步自我清洁和修复。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 8)
            }

            ForEach(vm.items) { item in
                MilestoneRowView(item: item)
            }
        }
        .navigationTitle("控烟里程碑")
        .listStyle(.insetGrouped)
        .onAppear { reload() }
        .onChange(of: SmokingLog.changeToken(for: logs)) { _ in reload() }
    }

    private func reload() {
        guard let profile = profiles.first else { return }
        vm.load(profile: profile, logs: Array(logs))
    }
}

// MARK: - 里程碑行

private struct MilestoneRowView: View {
    let item: HealthTimelineViewModel.MilestoneItem

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(item.isUnlocked ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: item.milestone.iconName)
                    .foregroundStyle(item.isUnlocked ? .green : .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.milestone.title)
                        .font(.headline)
                    if item.isUnlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                    }
                }
                Text(item.milestone.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if item.isUnlocked {
                    if let date = item.unlockDate {
                        Text("解锁于 \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                } else if let remaining = item.remainingText {
                    Text(remaining)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .opacity(item.isUnlocked ? 1 : 0.6)
        .padding(.vertical, 4)
    }
}
