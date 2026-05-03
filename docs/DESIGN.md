# SmokeFree — 控烟 iOS App 设计文档

## 项目概述

一款帮助用户**控烟减量**的 iOS 原生应用。目标不是强迫戒断，而是通过数据记录、减量激励、目标管理帮助用户逐步降低每日吸烟量。

**技术栈：** SwiftUI + SwiftData + CloudKit
**最低系统：** iOS 17+
**架构模式：** MVVM

---

## 功能清单

### 核心功能
| 功能 | 描述 |
|------|------|
| 每日吸烟记录 | 记录每天吸了多少支烟，与基准对比 |
| 购烟记录 | 记录购买品牌、数量、单价 |
| 目标与奖励 | 设定控烟小目标并绑定奖励；支持新建、编辑、删除 |

### 激励功能
| 功能 | 描述 |
|------|------|
| 控烟进度时间线 | 以控烟开始日期为起点的里程碑（1天、3天、1周…1年） |
| 节省金额统计 | 实际少抽支数 × 单支价格累计节省，支出等价物换算 |
| 成就徽章 | 控烟连续天数类（连续低于基准，1天～1年）+ 减量幅度类 + 节省金额类 |
| 今日减量进度卡 | 首页显示今日用量 vs 基准，进度环 + 等价物换算 |
| 记录后正向反馈 | 保存烟量后即时显示激励消息（比昨天/比基准减少多少） |

### 数据洞察
| 功能 | 描述 |
|------|------|
| 趋势图表 | 周/月烟量和支出变化折线图，显示日均 vs 基准对比及减少百分比 |
| 支出统计 | "节省了 XXX 元，够买 N 顿麦当劳"趣味等价换算 |

### 系统集成
| 功能 | 描述 |
|------|------|
| HealthKit | 写入控烟状态到 Apple 健康 App |
| 桌面小组件 | 显示控烟天数和节省金额（小/中尺寸）|
| iCloud 同步 | CloudKit 多设备数据同步 |

---

## 目录结构

```
SmokeFree/
├── SmokeFreeApp.swift              # App 入口，ModelContainer 初始化
├── AppConfig.swift                 # 静态数据：健康里程碑、成就定义
│
├── Models/                         # SwiftData 数据模型
│   ├── UserProfile.swift           # 用户档案（控烟开始日期、用烟习惯、烟价）
│   ├── SmokingLog.swift            # 每日吸烟记录
│   ├── PurchaseRecord.swift        # 购烟记录
│   ├── Goal.swift                  # 目标与奖励
│   └── UnlockedAchievement.swift   # 已解锁的成就徽章
│
├── ViewModels/
│   ├── DashboardViewModel.swift    # 首页计算：连续控烟天数、节省金额、下个里程碑
│   ├── LoggingViewModel.swift      # 每日记录 CRUD + 正向反馈消息
│   ├── PurchaseViewModel.swift     # 购烟记录 + 月度统计
│   ├── GoalsViewModel.swift        # 目标管理（新建/编辑/删除）+ 自动完成判断
│   ├── ChartsViewModel.swift       # 图表数据（周/月）
│   ├── HealthTimelineViewModel.swift # 里程碑解锁状态
│   ├── AchievementsViewModel.swift # 成就徽章映射
│   └── OnboardingViewModel.swift   # 引导流程（4步）
│
├── Views/
│   ├── Onboarding/                 # 欢迎 → 用烟习惯 → 控烟开始日期 → 通知权限
│   ├── Dashboard/                  # 连续控烟卡、减量进度卡、节省金额卡、里程碑卡
│   ├── Logging/                    # 每日记录 + 历史列表
│   ├── Purchases/                  # 购烟记录列表 + 添加 Sheet
│   ├── Goals/                      # 目标列表 + 添加/编辑 Sheet
│   ├── Charts/                     # 烟量图表 + 支出图表
│   ├── HealthTimeline/             # 控烟里程碑时间线列表
│   ├── Achievements/               # 成就徽章宫格
│   └── Shared/                     # 复用：CardView、ProgressRingView 等
│
├── Services/
│   ├── HealthKitService.swift      # HealthKit 授权 + 写入控烟状态
│   ├── NotificationService.swift   # 每日提醒 + 里程碑庆祝推送
│   └── AchievementService.swift    # 评估并颁发成就（纯函数，主线程）
│
└── Widget/
    ├── SmokeFreeWidget.swift       # 小组件 UI（小/中尺寸）
    └── WidgetProvider.swift        # 从 AppGroup UserDefaults 读取数据
```

---

## 数据模型

### UserProfile — 用户档案
```swift
@Model final class UserProfile {
    var id: UUID
    var quitDate: Date               // 控烟开始日期
    var cigarettesPerDayBefore: Int  // 控烟前每天吸烟量（基准值）
    var pricePerPack: Double         // 每包价格
    var cigarettesPerPack: Int       // 每包支数，默认 20
    var currencyCode: String         // 货币代码，默认 "CNY"
    var name: String
    var createdAt: Date

    // 计算属性
    var smokeFreeSeconds: TimeInterval    // 距控烟开始的秒数
    var streakDays: Int                   // 日历天数（用于里程碑时间线）
    func actualStreakDays(logs:) -> Int   // 连续低于基准天数（用于首页/成就）
    func moneySaved(logs:) -> Double      // 实际节省金额（少抽支数 × 单支价格累计）
}
```

> **连续控烟天数定义：** 从今天往前，每天 `log.count < cigarettesPerDayBefore` 或无记录均算入，遇到 `count >= 基准` 的记录则停止。

### SmokingLog — 每日吸烟记录
```swift
@Model final class SmokingLog {
    var id: UUID
    var date: Date      // 当天零点（Calendar.current.startOfDay）
    var count: Int      // 当天吸烟支数
    var notes: String?
    var createdAt: Date
}
```

### PurchaseRecord — 购烟记录
```swift
@Model final class PurchaseRecord {
    var id: UUID
    var date: Date
    var brand: String        // 品牌名
    var quantity: Int        // 购买包数
    var pricePerPack: Double // 单包价格
    var totalCost: Double    // 总花费 = quantity × pricePerPack
    var notes: String?
}
```

### Goal — 目标与奖励
```swift
@Model final class Goal {
    var id: UUID
    var title: String              // 目标描述，如"连续控烟 7 天"
    var reward: String             // 奖励，如"买一本新书"
    var targetDays: Int            // 目标天数（连续低于基准天数）
    var targetMoneySaved: Double?  // 或：金额目标（二选一）
    var isCompleted: Bool
    var completedAt: Date?
    var sortOrder: Int
    var createdAt: Date
}
```

### UnlockedAchievement — 已解锁成就
```swift
@Model final class UnlockedAchievement {
    var id: UUID
    var badgeID: String    // 对应 AchievementDefinition.id
    var unlockedAt: Date
    var isNewlySeen: Bool  // 用户查看后置 false
}
```

> **CloudKit 注意事项：** 所有属性必须有默认值或为 Optional。不使用 SwiftData `@Relationship`（CloudKit 限制），跨模型引用使用字符串 ID。

---

## 导航结构

```
ContentView
├── OnboardingContainerView   [首次启动，!onboardingComplete]
│   ├── WelcomeView
│   ├── SmokingHabitsView      ← 每日吸烟量（基准）+ 烟价
│   ├── QuitDateView           ← 控烟开始日期
│   └── NotificationsPermissionView
│
└── MainTabView（TabView）     [onboardingComplete 后]
    ├── Tab 1  首页（house）
    │   ├── 连续控烟天数卡片（连续低于基准天数）
    │   ├── 今日减量进度卡片（用量 vs 基准、进度环、等价物换算）
    │   ├── 节省金额卡片
    │   └── 下个控烟里程碑进度卡片
    │
    ├── Tab 2  记录（pencil）
    │   ├── 今日记录（保存后显示正向反馈 banner）
    │   └── 历史列表（最近 30 天）
    │
    ├── Tab 3  进度（chart.bar）
    │   ├── 趋势图表（烟量 + 支出，周/月切换；日均 vs 基准对比）
    │   ├── 节省金额统计（趣味等价物换算）
    │   ├── 控烟里程碑时间线
    │   └── 成就徽章宫格
    │
    ├── Tab 4  目标（target）
    │   ├── 进行中的目标（点击行 → 编辑 Sheet；左滑 → 删除）
    │   └── 已完成的目标
    │
    └── Tab 5  购烟（cart）
        └── 购买记录（按月分组）
```

---

## 控烟里程碑时间线

以控烟开始日期为起点，自动计算解锁状态：

| 时间 | 里程碑 | 描述 |
|------|--------|------|
| 1 天 | 控烟第一天 | 迈出第一步，改变从今天开始 |
| 3 天 | 坚持三天 | 烟瘾高峰期已过，最难的阶段正在结束 |
| 1 周 | 一周控烟 | 烟瘾开始减弱，身体逐渐适应 |
| 2 周 | 两周里程碑 | 吸烟冲动明显减少，睡眠质量开始改善 |
| 1 个月 | 一个月突破 | 持续控烟一个月，已逐渐形成新的行为习惯 |
| 2 个月 | 两个月坚持 | 呼吸更顺畅，运动耐力开始提升 |
| 3 个月 | 三个月荣耀 | 肺功能显著改善，精力更充沛 |
| 6 个月 | 半年里程碑 | 心血管健康持续改善 |
| 1 年 | 年度成就 | 你的身体感谢你的坚持 |

---

## 成就徽章

### 控烟坚持类（连续低于基准天数，严格：无记录视为中断）
| ID | 名称 | 条件 |
|----|------|------|
| streak_1_day | 迈出第一步 | 连续 1 天低于基准用量 |
| streak_3_days | 三日勇士 | 连续 3 天低于基准用量 |
| streak_1_week | 坚持一周 | 连续 7 天低于基准用量 |
| streak_1_month | 月度冠军 | 连续 30 天低于基准用量 |
| streak_3_months | 季度英雄 | 连续 90 天低于基准用量 |
| streak_6_months | 半年里程碑 | 连续 180 天低于基准用量 |
| streak_1_year | 年度荣耀 | 连续 365 天低于基准用量 |

### 减量幅度类（近 7 天日均）
| ID | 名称 | 条件 |
|----|------|------|
| reduction_half | 减半达人 | 近 7 天日均用量 ≤ 基准的 50% |
| reduction_quarter | 接近清零 | 近 7 天日均用量 ≤ 基准的 25% |

### 节省金额类
| ID | 名称 | 条件 |
|----|------|------|
| money_100 | 省下百元 | 累计节省 100 元 |
| money_500 | 省下五百 | 累计节省 500 元 |

> **评估时机：** 每次打开首页时自动评估，`AchievementService.evaluateAndAward(profile:logs:context:)` 统一处理所有类型徽章。
>
> **两种连续天数的区别：**
> - `actualStreakDays(logs:)`（宽松）：无记录算低于基准，用于首页天数卡和目标进度。
> - `AchievementService.consecutiveDaysBelow`（严格）：无记录视为中断，用于成就解锁。

---

## 节省金额计算

```
moneySaved = Σ max(0, cigarettesPerDayBefore - log.count) × (pricePerPack / cigarettesPerPack)
```

每天实际少抽的支数乘以单支价格累加，而非按日历天数估算。只有真实记录才产生节省。

---

## 关键架构决策

### 为什么用 `@Observable` 而非 `ObservableObject`
iOS 17 的 `Observation` 框架支持细粒度属性观察，无需对每个属性加 `@Published`。iOS 17+ 最低部署目标使这成为正确选择。ViewModel 通过 `.environment(vm)` 注入。

### 为什么不用 SwiftData `@Relationship`
CloudKit 对多对多关系支持有限。保持模型扁平（用字符串 ID 跨模型引用）可确保 CloudKit 同步稳定可靠。

### 为什么用 AppGroup UserDefaults 而非 SwiftData 给 Widget
WidgetKit 扩展运行在独立进程中，SwiftData + CloudKit 不可靠地支持扩展并发访问。AppGroup UserDefaults 是 Apple 推荐的 Widget 数据桥接方案。

### 为什么节省金额基于实际记录而非日历天数
基于日历天数的算法（`天数 × 基准 × 单支价格`）在控烟场景下会虚报金额——用户可能某天抽了更多烟。只统计有记录且低于基准的部分，数字真实可信，也更有激励意义。

### 为什么目标管理与进度页的节省统计分离
进度页的节省金额卡是纯展示（已省多少）；目标 Tab 负责"我要省到 X 元"的追踪。两者职责明确，避免同一数据在两处管理产生混乱。

---

## 开发阶段规划

### Phase 1 — 基础（Foundation）✅
- [x] Xcode 项目配置：SwiftData + CloudKit + AppGroup 权限
- [x] 所有 `@Model` 类定义
- [x] `SmokeFreeApp.swift`（`ModelContainer` + CloudKit 配置）
- [x] `AppConfig.swift`（所有静态数据）
- [x] 引导流程（4个页面）+ `OnboardingViewModel`
- [x] `ContentView`（`@AppStorage` 控制是否显示引导）

### Phase 2 — 核心循环（Core Loop）✅
- [x] `DashboardView` + `DashboardViewModel`
- [x] `LoggingView` + `LoggingViewModel`
- [x] `AchievementService` + `AchievementsView`

### Phase 3 — 激励功能（Engagement）✅
- [x] `HealthTimelineView` + `HealthTimelineViewModel`
- [x] `GoalsView` + `GoalsViewModel` + `AddGoalView`（含编辑模式）

### Phase 4 — 数据与图表（Charts）✅
- [x] `TrendsView` + `ChartsViewModel`（Charts 框架）
- [x] `PurchasesView` + `PurchaseViewModel`
- [x] `ExpenseStatsView`（趣味支出对比）

### Phase 5 — 系统集成（Integrations）✅
- [x] `HealthKitService` + HealthKit 权限（每日写入正念记录）
- [x] `NotificationService`（每日 21:00 提醒 + 里程碑一次性推送）
- [x] `SmokeFreeWidget` + `WidgetProvider` + AppGroup 数据桥
- [ ] **Xcode 手动配置**：主 Target 添加 HealthKit 能力；创建 Widget Extension Target；两个 Target 均开启 App Groups（`group.com.smokefree.app`）

### Phase 6 — 打磨（Polish）
- [ ] 动画：徽章解锁庆祝效果
- [ ] 无障碍：VoiceOver 标签
- [ ] 本地化：`Localizable.strings`，货币默认 CNY
- [ ] CloudKit 多设备冲突测试

### Phase 7 — 控烟核心逻辑（Reduction）✅
- [x] 首页今日减量进度卡：进度环 + 今日支数 + 比基准减少百分比 + 等价物换算
- [x] 记录后正向反馈 banner（比昨天少/比基准少/与基准持平/超出）
- [x] `actualStreakDays` 改为连续低于基准天数（不再要求零抽）
- [x] 所有成就徽章改为控烟类（`requiredConsecutiveDaysBelow`）
- [x] 减量幅度徽章（减半/接近清零）+ 节省金额徽章
- [x] 控烟里程碑时间线（替换完全戒断生物学数据）
- [x] 节省金额改为实际少抽累计（`moneySaved(logs:)`）
- [x] 目标管理统一在目标 Tab，进度页移除重复的节省目标设置
- [x] 全局文案 戒烟→控烟（引导、首页、小组件、通知）

---

## 验证清单

- [ ] 完成引导 → 首页正确展示连续控烟天数和里程碑进度
- [ ] 记录今日烟量低于基准 → 首页减量卡进度环有填充，显示减少百分比和等价物
- [ ] 记录今日烟量等于/超过基准 → 首页显示提示，连续天数归零
- [ ] 连续 7 天低于基准 → 成就页解锁"坚持一周"徽章
- [ ] 近 7 天日均 ≤ 基准 50% → 解锁"减半达人"徽章
- [ ] 累计节省 ≥ 100 元 → 解锁"省下百元"徽章
- [ ] 设置连续 7 天目标 → 达成后自动标记完成
- [ ] 保存烟量 → 立即出现正向反馈 banner，内容随对比结果变化
- [ ] 控烟满 1 周 → 时间线"一周控烟"里程碑解锁
- [ ] 开启通知权限 → 每天 21:00 收到提醒；里程碑到达时收到庆祝推送
- [ ] Health App → 能看到每日正念记录
- [ ] 安装小组件 → 显示"控烟 N 天"，App 切回前台后 1 分钟内更新
- [ ] 两台设备测试 → CloudKit 同步约 30 秒内完成
- [ ] 图表页 → 日均和基准数字同时显示，减少百分比以绿色标注
