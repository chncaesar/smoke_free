import SwiftUI
import CoreData

struct AchievementsView: View {
    @FetchRequest(sortDescriptors: []) private var unlocked: FetchedResults<UnlockedAchievement>
    @StateObject private var vm = AchievementsViewModel()

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(vm.unlockedCount) / \(AppConfig.achievementDefinitions.count) 已解锁")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(vm.badges) { item in
                        BadgeView(item: item)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("成就")
        .onAppear { vm.load(unlocked: Array(unlocked)) }
        .onChange(of: unlocked.count) { _ in vm.load(unlocked: Array(unlocked)) }
    }
}

// MARK: - 单个徽章

struct BadgeView: View {
    let item: AchievementsViewModel.BadgeItem

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(item.isUnlocked ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 64, height: 64)
                Image(systemName: item.isUnlocked ? item.definition.iconName : "lock.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(item.isUnlocked ? .green : .secondary)
            }
            Text(item.definition.title)
                .font(.caption.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(item.isUnlocked ? .primary : .secondary)
            Text(item.definition.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .opacity(item.isUnlocked ? 1 : 0.5)
    }
}
