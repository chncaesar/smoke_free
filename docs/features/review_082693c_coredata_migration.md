# Review 1: SwiftData→Core Data 全量迁移

Date: 20260624
Branch: (detached at 082693c)

## Summary

本次 commit 将整个项目从 SwiftData (iOS 17) 迁移到 Core Data (iOS 15.8)，涉及 32 个文件的变更（+715/-520 行）。核心变更为：`@Model`→`NSManagedObject`，`@Query`→`@FetchRequest`，`@Observable`→`ObservableObject`+`@Published`，`NavigationStack`→`NavigationView`，`ContentUnavailableView`→手写占位视图，`Chart`→手绘 BarChartView。

总体结构调整方向正确，但存在 **2 个 Critical 编译/数据丢失问题** 和若干 Major/Minor 问题。共发现 **2 Critical, 4 Major, 4 Minor**。

## Issues

### Critical

- **[C1] 全项目缺失 `context.save()` 调用 — 所有数据变更仅存于内存**
  Core Data 与 SwiftData 的关键区别在于：SwiftData 的 `ModelContext` 自动持久化变更，而 Core Data 的 `NSManagedObjectContext` 需显式调用 `save()` 才能将变更写入 SQLite。本次迁移中：
  - `LoggingViewModel.save()` — 修改/插入 SmokingLog 后无 `save()`
  - `OnboardingViewModel.finish()` — 插入 UserProfile 后无 `save()`
  - `PurchaseViewModel.addPurchase()` — 插入 PurchaseRecord 后无 `save()`
  - `GoalsViewModel.addGoal()` / `saveEdit()` / `deleteGoal()` — 插入/修改/删除 Goal 后均无 `save()`
  - `AchievementService.evaluateAndAward()` — 插入 UnlockedAchievement 后无 `save()`
  - `DashboardView` 中的 `EditBaselineView.applyChanges()` — 修改 profile 基线后无 `save()`
  - `DashboardView.AchievementService` 调用 — 无 `save()`
  - `LoggingView` 的 `onDelete` — `context.delete()` 后无 `save()`
  - `PurchasesView` 的 `onDelete` — 无 `save()`
  - `DataImportService.importFromJSON()` — 大量 insert/update 后均无 `save()`

  **后果**：用户创建的目标、记录、购烟记录、成就解锁等数据在应用被杀死或系统回收内存后全部丢失。`automaticallyMergesChangesFromParent = true` 仅处理跨 context 变更合并，不做本地持久化。

  **修复方向**：在每个写操作路径末尾统一调用 `try context.save()`（建议在 ViewModel 层 save 方法内完成，或统一在 `@main` 的 `scenePhase` `.background` 回调中保存）。

- **[C2] `EditBaselineView.applyChanges()` 使用 `== nil` 和 `??` 操作符于非 Optional 类型 — 编译失败**
  `SmokeFree/SmokeFree/SmokeFree/Views/Dashboard/DashboardView.swift:334-340`

  ```swift
  for log in logs where log.baselineAtTime == nil || log.pricePerPackAtTime == nil || log.cigarettesPerPackAtTime == nil {
      log.baselineAtTime = log.baselineAtTime ?? profile.cigarettesPerDayBefore
      log.pricePerPackAtTime = log.pricePerPackAtTime ?? profile.pricePerPack
      log.cigarettesPerPackAtTime = log.cigarettesPerPackAtTime ?? profile.cigarettesPerPack
  }
  ```

  迁移后 `baselineAtTime` 为 `Int32`（非 Optional），`pricePerPackAtTime` 为 `Double`（非 Optional），`cigarettesPerPackAtTime` 为 `Int32`（非 Optional）。Swift 的 `== nil` 比较和 `??` 运算符仅适用于 Optional 类型，此代码无法通过编译。

  **修复方向**：改为 `== 0` 判断并用 `if` 条件赋值：
  ```swift
  for log in logs where log.baselineAtTime == 0 || log.pricePerPackAtTime == 0 || log.cigarettesPerPackAtTime == 0 {
      if log.baselineAtTime == 0 { log.baselineAtTime = profile.cigarettesPerDayBefore }
      if log.pricePerPackAtTime == 0 { log.pricePerPackAtTime = profile.pricePerPack }
      if log.cigarettesPerPackAtTime == 0 { log.cigarettesPerPackAtTime = profile.cigarettesPerPack }
  }
  ```

### Major

- **[M1] 测试文件未迁移 — 编译失败**
  - `SmokeFree/SmokeFreeTests/AchievementServiceTests.swift` — 仍使用 `import SwiftData`、`ModelContext`、`ModelContainer`、`FetchDescriptor`、`@Model` 实例化
  - `SmokeFree/SmokeFreeTests/GoalsViewModelTests.swift` — 仍使用 `import SwiftData`
  
  32 个已有测试将全部编译失败。测试文件未纳入本次迁移范围。

  **修复方向**：为测试创建 Core Data 内存 store（`NSPersistentContainer` + `NSInMemoryStoreType`），重写 `makeContext()` 返回 `NSManagedObjectContext`。

- **[M2] `context.insert()` 在已注册对象上重复调用**
  所有 Model 的 `convenience init` 均调用 `self.init(context: context)`（将对象注册到 context），然后调用方又显式调用 `context.insert(record)`。影响位置：
  - `OnboardingViewModel.swift:46`
  - `PurchaseViewModel.swift:60`
  - `GoalsViewModel.swift:55`
  - `LoggingViewModel.swift:43`
  - `AchievementService.swift:48`
  - `DataImportService.swift:40,67,75,84,95`

  Core Data 文档明确指出：`init(context:)` 已自动将对象插入 context，再调用 `insert()` 是冗余操作，且可能在特定 Core Data 版本中触发 "managed object already has a context" 警告或异常。

  **修复方向**：二选一 — 要么在 convenience init 中调用 `self.init(entity:insertInto: context)` 并在实际需要时才 insert；要么移除所有外部 `context.insert()` 调用。

- **[M3] 生产环境 CloudKit 同步被静默禁用**
  `SmokeFree/SmokeFree/SmokeFree/SmokeFreeApp.swift:24-27`

  原代码中非模拟器构建使用 `ModelConfiguration.CloudKitDatabase.automatic` 启用 CloudKit 同步。迁移后仅在 `#if targetEnvironment(simulator)` 分支中显式禁用 CloudKit，非模拟器路径未设置 `cloudKitContainerOptions`。`NSPersistentCloudKitContainer` 默认不启用 CloudKit（需显式配置 `NSPersistentCloudKitContainerOptions`），导致生产环境 CloudKit 同步失效。

  **修复方向**：在 `#else` 分支中恢复 CloudKit 配置，或将容器改为 `NSPersistentContainer`（如果确定不需要 CloudKit）。

- **[M4] `DataImportService` 在重复日志检测中使用 `startOfDay` 转换，但 `date` 属性可能为 nil**
  `SmokeFree/SmokeFree/SmokeFree/Services/DataImportService.swift:55-56`

  ```swift
  var existingLogDates = Set(existingLogs.map { Calendar.current.startOfDay(for: $0.date ?? Date()) })
  ```
  
  若某条日志的 `date` 为 nil，fallback 到 `Date()` 可能与其他已有记录冲突（因为多条 nil-date 日志都会被映射到同一天），导致合法记录被跳过。在 `#if targetEnvironment(simulator)` 下影响较小，但在生产环境中若存在历史损坏数据会丢失导入记录。

### Minor

- **[m1] `ChartsViewModel` 导入不必要的 `CoreData`**
  `SmokeFree/SmokeFree/SmokeFree/ViewModels/ChartsViewModel.swift:3`
  
  ViewModel 实际只使用 `Combine`（`ObservableObject` + `@Published`），`import CoreData` 多余但无害。

- **[m2] `TrendsView` 的手绘柱状图在大量数据点时 `barWidth` 可能为负（被 clamp 到 4）**
  `SmokeFree/SmokeFree/SmokeFree/Views/Charts/TrendsView.swift` — `BarChartView`
  
  当数据点超过 ~90 个时（如 30 天月视图），`(geo.size.width / CGFloat(data.count)) - 4` 可能为负值，经 `max(4, ...)` clamp 后柱子重叠。对于月视图（30 点）在 iPhone SE（375pt 宽）上勉强可用，但在 iPad 横屏时柱子极窄。不影响正确性，但 UI 观感差。

- **[m3] `@FetchRequest` 初始化顺序：某些 View 中 `profiles.first` 访问发生在 `profiles` 被填充之前**
  `SmokeFree/SmokeFree/SmokeFree/Views/Dashboard/DashboardView.swift:13`

  `private var profile: UserProfile? { profiles.first }` 是计算属性，在 View 首次渲染时 `@FetchRequest` 可能尚未返回结果，返回 nil 并渲染 "完成引导以开始" 占位。随后 `onAppear` 触发 `updateVM()` 时 profiles 已可用。此行为与 SwiftData `@Query` 时期一致（非新引入问题），但值得注意。

- **[m4] `onChange(of: scenePhase)` 使用 iOS 14 单参数回调签名**
  `SmokeFree/SmokeFree/SmokeFree/Views/Dashboard/DashboardView.swift:100`
  
  iOS 15 提供了双参数版本 `onChange(of:perform:)`，iOS 17 使用 `onChange(of:initial:_:)` 双闭包。当前使用最老的单闭包版本，功能正确但缺失 iOS 17 的 `initial: true` 语义（首次渲染触发）。在 iOS 15.8 目标下这是正确的选择，不构成问题。

## Coder Response
<!-- Coder 在修复后填写此节；Reviewer 初次产出时省略 -->

## Escalate

- **[ESCALATE] CloudKit 同步策略决策**：迁移后生产环境 CloudKit 同步被静默禁用（见 [M3]）。需确认：是否需要恢复 CloudKit 同步，还是明确放弃跨设备数据同步（改为纯本地存储）？若放弃同步，应将 `NSPersistentCloudKitContainer` 改为 `NSPersistentContainer` 以明确意图。
