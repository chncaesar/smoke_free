# Review Combined: 日历时间驱动→行为驱动 + 购烟价格/超基准扣减/导出导入

Date: 20260624
Commits:
- `dc708aa` — fix: 核心逻辑从日历时间驱动改为实际行为驱动
- `0437fb5` — feat: 购烟价格优先 + 超出基准扣减 + 数据导出导入

## Summary

对两个 commit 的合并 diff（18 文件，+1020 / -142 行）进行了全维度审查。方向性改进值得肯定：里程碑从纯日历时间改为行为驱动（需实际控烟记录），购烟价格优先级提升，超基准扣减使节省金额可负可正更真实，数据导入导出补全了用户数据主权。但审查发现 **2 个 Critical、6 个 Major、4 个 Minor** 问题。最严重的是 perCigPrice 中购烟价格被错误应用于购烟日期之前的日志（数据正确性缺陷），以及测试套件因里程碑 ID 重命名而全面失效。

### Pattern 扫描结果

| 检查项 | 结果 |
|--------|------|
| `max(0, baseline - log.count)` 统一 | ✅ moneySaved 有意不用 max(0)（支持负数扣减），updateReduction 用 max(0)（进度不取负），各有其语义 |
| `pricePerPack / Double(perPack)` 除零保护 | ✅ 所有路径均有 `max(1, perPack)` 或 `!= 0` guard |
| `offsetSeconds` 残留 | ✅ 全部清除 |
| `scheduleMilestoneNotifications` 残留 | ✅ 全部清除 |
| `formatTimeRemaining` 残留 | ✅ 全部清除 |

## Issues

### Critical

- [C1] **perCigPrice 将购烟价格错误应用于购烟日期之前的日志** — `UserProfile.swift:108`

  `moneySaved` → `perCigPrice` 的第二优先级（购烟价格）检查条件为 `logDate <= exhaustion`。但 `purchaseExhaustionDate` 的 `exhaustion` 是从 `purchaseDay` 起累加计算的，必然 `≥ purchaseDay`。对于购烟日期之前的日志（`logDate < purchaseDay`），条件 `logDate ≤ exhaustion` 仍然成立，导致这些日志错误使用购烟价格而非回退到 profile 价格。

  反例：用户在 Day1 记录 10 支（无价格快照），Day5 购烟一包 ¥30。Day1 日志 `date ≤ exhaustion(Day10 左右)` → 错误使用 ¥30/20 而非 profile 价格。

  修复：在 perCigPrice 的购烟价格分支增加 `logDate >= purchaseDay`（或 `cal.startOfDay(for: purchase.date)`）的前置条件。

- [C2] **DashboardViewModelTests 因里程碑 ID 重命名而全部失败** — `DashboardViewModelTests.swift:44,82,93,97,108`（未在 diff 中但被变更破坏）

  `dc708aa` 将 `HealthMilestone.offsetSeconds` 重构为 `requiredStreakDays`，里程碑 ID 从 `"20min"` / `"8hours"` 等改为 `"day1"` / `"3days"` 等。但测试套件仍断言 `vm.nextMilestone?.id == "20min"`（line 44），以及检查 `nextMilestoneTimeRemaining.contains("分钟")` / `.contains("小时")`（lines 93, 108）。`update(from:logs:)` 新逻辑传入 `logs: []` 导致 `actualStreakDays` 返回 0，第一个未解锁里程碑变为 `"day1"`（而非 `"20min"`），剩余时间格式变为 `"还需 N 天连续控烟"`（无"分钟""小时"字样）。**6 个测试用例必然失败**（`update_25SecondsIn_firstMilestoneIsNext`、`update_progressBetweenZeroAndOne`、`timeRemaining_withinOneHour_showsMinutes`、`timeRemaining_withinOneDay_showsHours`、`timeRemaining_moreThanOneDay_showsDays`、`update_allMilestonesUnlocked_nextMilestoneIsNil`）。

### Major

- [M1] **冷启动触发所有已解锁里程碑的重复通知** — `DashboardViewModel.swift:13,37-44`

  `DashboardViewModel` 的 `@Published var streakDays` 默认值为 0。每次 App 冷启动（ViewModel 重建），首次 `update()` 调用时 `prevStreakDays = 0`，`streakDays` 可能为正值（如 5），触发 `newlyUnlocked` filter（lines 38-39），对所有 `requiredStreakDays ∈ (0, 5]` 的里程碑发送通知。通知 ID 使用 `Date().timeIntervalSince1970` 拼接，永远唯一 — 系统无从去重。虽然 `trigger: nil` 的即时通知在前台不弹横幅，但若用户快速切到后台，这些排队通知会显示。

  缺失：缺少"已通知里程碑"的持久化状态（如 UserDefaults 记录已通知的 milestone ID 集合），导致每次冷启动重复推送。

- [M2] **成就金额评估忽略购烟记录，与仪表盘显示不一致** — `AchievementService.swift:35`、`LoggingView.swift:31`

  `AchievementService.evaluateAndAward` 调用 `profile.moneySaved(logs: logs)` 未传 `purchases` 参数。`moneySaved` 的新签名使用三级价格优先级（日志快照 → 购烟价格 → profile），缺少 purchases 时回退到纯 profile 价格。而仪表盘 `DashboardViewModel` 传入了 purchases。结果：成就"省下百元""省下五百"的解锁条件与仪表盘显示的节省金额可能不一致（差值取决于购烟价格与 profile 价格的差异）。

  修复方向：为 `evaluateAndAward` 增加 `purchases` 参数，并在 `DashboardView.updateVM()` 和 `LoggingView` 中传入。

- [M3] **DataImport 对 PurchaseRecord 和 Goal 无去重逻辑** — `DataImportService.swift:75-78,81-86`

  `SmokingLog` 导入有按日期的去重（line 55-71），`UnlockedAchievement` 有按 badgeID 的去重（line 89-97）。但 `PurchaseRecord`（lines 75-78）和 `Goal`（lines 81-86）直接逐条 `context.insert()`，无任何去重。用户重复导入同一备份将产生重复的购烟记录和目标。

- [M4] **DataImport 静默吞保存错误** — `DataImportService.swift:99`

  `try? context.save()` 在导入末尾丢弃所有保存错误。如果 Core Data 保存失败（约束冲突、磁盘满等），用户仍收到"导入完成"成功提示（ProgressTabView line 74），但数据可能未持久化。应使用 `try` 并在失败时抛出错误，让调用方显示导入失败信息。

- [M5] **UserProfileTests 编译错误未修复** — `UserProfileTests.swift:54,66,79`（预存问题，未在 diff 中但持续存在）

  `moneySaved` 一直是实例方法（非计算属性），但测试调用 `profile.moneySaved.isApproximatelyEqual(...)`（作为属性访问，且未传 `logs:` 参数）。此问题在 review_20260623_01 中已标记为 C1，本次两个 commit 未修复。考虑 `moneySaved` 签名进一步变更为 `(logs:purchases:)`，这些测试离编译通过更远了。3 个测试用例无法编译。

- [M6] **AchievementServiceTests 使用 SwiftData API 但生产代码已切换为 Core Data** — `AchievementServiceTests.swift:10-17`（预存问题）

  测试中 `makeContext()` 使用 `Schema` / `ModelConfiguration` / `ModelContainer`（SwiftData），但 `AchievementService.evaluateAndAward` 的 `context` 参数类型在 Core Data 迁移后变为 `NSManagedObjectContext`，且内部使用 `NSFetchRequest(entityName:)`。测试的 `ModelContext` 类型与函数签名不兼容，编译必然失败。此问题虽在 Core Data 迁移引入，但本次两个 commit 均未处理。

### Minor

- [m1] **milestoneUnlockDate 对 requiredStreakDays ≥ 2 返回日期偏早** — `UserProfile.swift:146`

  函数从今天向后遍历，当 `consecutiveBelow` 累计到 `requiredDays` 时返回 `checkDate`。但 `checkDate` 是 `requiredDays` 天连续窗口的**第一天**（最早日期），而非里程碑**达成日**（应为连续窗口的最后一天，即达成当天）。例如：连续控烟 4 天（Jun 21-24），查询 `requiredDays=3` 时返回 Jun 22（窗口第一天），实际达成日应为 Jun 23。

  影响范围：仅 HealthTimelineView 的"解锁于 [日期]"显示文案，不影响功能逻辑。修复：`return cal.date(byAdding: .day, value: requiredDays - 1, to: checkDate) ?? checkDate`

- [m2] **日志 nil date 在 purchaseExhaustionDate 中的非预期行为** — `UserProfile.swift:120-122`

  `purchaseExhaustionDate` 的 filter/sort 使用 `$0.date ?? Date()`（nil 回退为当前时刻），若存在 date 为 nil 的异常日志，会被错误纳入购烟消耗计算，且排序位置不可预测。建议对 nil date 的日志加 `guard` 跳过或记录警告。

- [m3] **购烟消耗计算硬编码每包 20 支** — `UserProfile.swift:118`、`DashboardViewModel.swift:105`

  `totalBought = Int(latest.quantity) * 20` 假设所有购买以 20 支/包计。但 `PurchaseRecord` 存储的是 `pricePerPack`（每包价格）和 `quantity`（包数），用户可能购买非 20 支包装。与 profile 的 `cigarettesPerPack` 字段不一致。

- [m4] **DashboardView 中 exportData 失败时静默无反馈** — `DashboardView.swift:107-111`

  `exportData()` 的 `catch` 分支仅置 `exportDirURL = nil`，不对用户展示任何错误提示。导出失败（如数据损坏、磁盘满）时用户点击分享按钮无反应且无错误信息。

## Coder Response
<!-- Coder 在修复后填写此节；Reviewer 初次产出时省略 -->

## Escalate

- [ESCALATE] 测试套件修复策略 — 当前测试套件的 3 个文件（DashboardViewModelTests 6 个用例、UserProfileTests 3 个用例、AchievementServiceTests 全部用例）因 API 不兼容而无法编译/通过。其中 DashboardViewModelTests 的损坏由本次 `dc708aa` 直接导致（里程碑模型重写），其余为预存问题。需决定：是在本次合入前修复所有测试，还是接受测试债务、创建独立的测试修复任务？建议至少修复 DashboardViewModelTests（与本次变更直接相关），其余以 task/issue 跟踪。
