# Product Behavior Review: SmokeFree 全功能行为审查

Date: 20260624
Branch: feature/* (based on current HEAD)

## Summary

对 SmokeFree App 的 7 大功能模块按真实用户场景逐一推演代码路径。审查发现 **1 个 Critical、6 个 Major、3 个 Minor** 问题。最严重的是购烟价格逻辑反转（正在抽的烟用 profile 价，抽完了反而用购烟价），以及 Dashboard/Timeline/Achievements 三处对"连续控烟"使用不同定义导致同一用户看到三个不同结论。共计 10 个问题，其中 3 个涉及跨模块数据不一致。

---

## 功能 1: 引导流程 → 首页展示

### 场景 1.1 — 引导当天完成，无任何记录

**用户操作**：完成引导，设置每日基准 20 支、¥25/包、20支/包、quitDate=今天。进入首页，无吸烟日志。

**代码路径**：
```
OnboardingContainerView.finish → UserProfile 插入 CoreData
→ ContentView 切换到 MainTabView
→ DashboardView.onAppear → updateVM()
→ vm.update(from:profile, logs:[], purchases:[])
→ profile.actualStreakDays(logs:[])
```

`actualStreakDays` 遍历：
- `checkDate = today` → 无 log → 不 break → count += 1
- `prev = yesterday` → `yesterday < startOfQuitDate(today)` → 循环结束
- 返回 `count = 1`

**结论**：首页显示「连续控烟 **1 天**」。用户刚完成引导、一支烟都没记录过，就被告知"连续控烟 1 天"。从用户视角看这是**困惑**的 —— "我什么都没做就已经控烟 1 天了？"

`nextMilestone`：`streakDays=1`，第一个 `requiredStreakDays > 1` 的里程碑是「坚持三天」（3 天）。首页里程碑卡显示"坚持三天" + 进度环。

`moneySaved`：无日志，返回 0。"已节省"卡片显示 ¥0.0。

`totalSpentOnSmokes`：无日志，`annualBaselineCost` = `profile.cigarettesPerDayBefore × (25/20) × 365` = `20 × 1.25 × 365 = ¥9125`。烟草开销卡片显示"按现在用量，每年花费 ¥9125"。

健康时间线页：`load(streakDays: 1, ...)` → 只有 day1（需要 1 天）解锁，其余锁定。显示"控烟第一天 ✅"。

**关键判断**：streak=1 是无记录日的副作用（lenient 算法）。API 文档说"无记录算低于基准"，但在用户刚完成引导的上下文中，这不是"成功控烟"而是"还没有任何行为"。

### 场景 1.2 — quitDate=100 天前，无任何日志

**用户操作**：引导时将 quitDate 设为 100 天前。无吸烟记录。

**代码路径**：
- `actualStreakDays`：从 today 往回遍历 100 天，所有日期无 log → 均不 break → count 累加到 100。
- 但是：循环上限是 `checkDate >= startOfQuitDate`，quitDate 已是 100 天前，所以 count 实际可达到约 100。

**各页面显示**：
- 首页 StreakCard：「连续控烟 **100 天**」
- 首页里程碑：`streakDays=100`，最后一个 ≤100 的是 3months(90)，下一个是 6months(180)。显示"半年里程碑"进度 `(100-90)/(180-90) = 10/90 ≈ 11%`。
- 时间线页：「三个月荣耀」✅ (90天 ≤ 100)，"半年里程碑"🔒（还需 80 天）
- 成就页：**零徽章解锁**。`consecutiveDaysBelow` 第一天就无日志 → break → 返回 0。`streak_1_day` 要求连续 1 天低于基准 → 不满足。

**结论**：
- 首页说 100 天，时间线说"三个月荣耀"已解锁，成就页一个徽章都没有 —— **三处矛盾**。
- 用户视角：极端困惑。同一个 App 告诉我"你控烟 100 天了"同时又告诉我"你一个成就都没有"。

**根因**：
| 位置 | 使用的算法 | 无记录日含义 |
|------|-----------|-------------|
| 首页 StreakCard | `actualStreakDays` | 算低于基准（继续计数） |
| 时间线页 | `actualStreakDays` | 同上 |
| 成就徽章 | `consecutiveDaysBelow` | 中断（归零） |

---

## 功能 2: 每日记录与首页反馈

### 场景 2.1 — 记录 10 支（基准 20 支）

**数据**：`baseline=20`, `pricePerPack=25`, `cigarettesPerPack=20` → 每支 ¥1.25

**首页减量卡**（`updateReduction`）：
- `todayCount = 10`, `baselineCount = 20`
- `reduced = max(0, 20-10) = 10`
- `reductionPercent = 10/20 = 0.5` → 进度环 50%（橙色）
- `todaySavings = 10 × 1.25 = ¥12.5`（无购烟记录，effPricePerCig 回退到 profile 价格）
- 副标题：「比基准少了 10 支（减少 50%）」
- 等价物：「省了 ¥12.5，相当于 6 瓶矿泉水」

**首页 StreakCard**：`actualStreakDays` 从 today 往回 → 只有今天有 log（10<20），昨天无 log → 继续计数直到 quitDate。streak 取决于 quitDate。

**首页 MoneySavedCard**：`moneySaved = (20-10) × 1.25 = ¥12.5` → 「已节省 ¥12.5」

**记录页反馈 banner**：`feedbackMessage(baseline:20, yesterdayCount:nil)` → `todayCount=10, diff=20-10=10, pct=50` → 「比基准少了 10 支（减少 50%），不错！」

**结论**：✅ 正确。所有数值自洽。

### 场景 2.2 — 记录 25 支（超出基准）

**数据**：`baseline=20`, `todayCount=25`

**首页减量卡**：
- `reduced = max(0, 20-25) = 0`
- `reductionPercent = 0/20 = 0` → 进度环 0%（灰色）
- `todaySavings = 0`
- 副标题：「比基准多了 5 支，明天继续努力」

**首页 StreakCard**：`actualStreakDays` 今天 log.count=25 ≥ baseline=20 → **break**！streak = 0。「连续控烟 0 天」

**首页 MoneySavedCard**：
- `moneySaved` 公式：`reduced = baseline - count = 20 - 25 = -5`
- `saved = -5 × 1.25 = -¥6.25`
- 如之前无记录：`moneySaved = -6.25` → 「已节省 **-¥6.3**」

**反馈 banner**：`diff = 20 - 25 = -5, -5 <= 0` → 「今天多了一点，明天可以更好！」

**结论**：✅ 逻辑正确。但「已节省 -¥6.3」在 UI 上令人困惑 —— "节省"出现了负数。用户可能理解为"花掉了 ¥6.3"而非"省了 -¥6.3"。这是 UI 语义问题。

### 场景 2.3 — 连续 3 天 10 支，第 4 天 25 支

**第 4 天**：
- `actualStreakDays`：今天有 log (25 ≥ 20) → **立即 break**。返回 count=0。
- StreakCard：「连续控烟 0 天」
- 减量卡：`reduced = max(0, 20-25) = 0`，进度 0%
- MoneySavedCard：前 3 天 + 第 4 天 = `3×10×1.25 + (-5)×1.25 = 37.5 - 6.25 = ¥31.25`

**结论**：✅ Streak 中断逻辑正确。但用户前 3 天辛苦攒的 3 天 streak 因为一天超标就归零，心理体验可能较挫败。这是产品设计决策。

---

## 功能 3: 里程碑与时间线

### 场景 3.1 — 真实控烟 7 天（每天 10 支，均有记录）

**数据**：7 天均有 log，count=10 < baseline=20。quitDate=7 天前。

**首页**：
- `streakDays = actualStreakDays = 7`（7 天均有 log 且 < baseline）
- `nextMilestone`：`requiredStreakDays > 7` 的第一个 → "两周里程碑"（14天）
- `prevRequired`：`requiredStreakDays ≤ 7` 的最后一个 → "一周控烟"（7天）
- `progress = (7 - 7) / (14 - 7) = 0%`
- 「还需 7 天连续控烟」

**时间线页**：
- day1(1) ✅、3days(3) ✅、1week(7) ✅
- 2weeks(14) 🔒、1month(30) 🔒 …

**成就**：`consecutiveDaysBelow = 7`（每天都有 log 且 < baseline）
- streak_1_day ✅、streak_3_days ✅、streak_1_week ✅
- streak_1_month ❌（need 30）

**结论**：✅ 首页/时间线/成就三者一致（因为 7 天都有记录）。但有一个 UX 细节：进度环显示 0%，用户刚达成"一周控烟"就看到"两周里程碑 0%"，感觉"归零了"。

### 场景 3.2 — quitDate=100 天前，零日志

**同场景 1.2**。时间线页显示"三个月荣耀"已解锁，但没有任何日志证据。

**结论**：与场景 1.2 相同的不一致问题。时间线页的"已解锁"状态缺乏行为支撑。

### 场景 3.3 — streak=7 后 app 被杀重开

**代码路径**：
```swift
// DashboardViewModel.update()
if streakDays > prevStreakDays {
    let newlyUnlocked = milestones.filter {
        $0.requiredStreakDays > prevStreakDays && $0.requiredStreakDays <= streakDays
    }
    for milestone in newlyUnlocked {
        if !Self.isMilestoneNotified(milestone.id) {  // ← UserDefaults 去重
            NotificationService.shared.sendMilestoneNotification(milestone: milestone)
            Self.markMilestoneNotified(milestone.id)
        }
    }
}
```

冷启动时 `prevStreakDays = 0`（ViewModel 重建），`streakDays = 7`。`newlyUnlocked` 包含 day1, 3days, 1week。但 `isMilestoneNotified` 检查 UserDefaults → 首次达成时已标记 → 跳过。**不会重复通知**。

**结论**：✅ M1 修复有效。重开不重复推送。

---

## 功能 4: 节省金额

### 场景 4.1 — 3 天混合数据，多视图一致性

**数据**：Day1:10支, Day2:25支, Day3:5支。`baseline=20, ¥25/包, 20支/包 → ¥1.25/支`

**计算**：
- Day1: `(20-10) × 1.25 = 12.5`
- Day2: `(20-25) × 1.25 = -6.25`
- Day3: `(20-5) × 1.25 = 18.75`
- **总计 = ¥25.00**

**各视图调用的方法签名**：
| 视图 | 调用链 | purchases 参数 |
|------|--------|---------------|
| 首页 MoneySavedCard | `vm.moneySaved` ← `profile.moneySaved(logs:, purchases:)` | ✅ Array(purchases) |
| 进度页 ExpenseStatsView | `profile.moneySaved(logs:logs, purchases:purchases)` | ✅ Array(purchases) |
| 目标页 GoalRowView | `profile.moneySaved(logs:logs, purchases:purchases)` | ✅ Array(purchases) |
| 目标完成检查 | `profile.moneySaved(logs:logs, purchases:purchases)` | ✅ Array(purchases) |
| Widget | `vm.moneySaved`（同上，update 时已算好） | ✅（通过 vm.update） |
| 成就评估 | `profile.moneySaved(logs:logs, purchases:purchases)` | ✅（两处调用均已传入） |

**结论**：✅ 所有视图调用同一方法、同一 purchases 参数。显示 ¥25.0，完全一致。M2（前次审查成就金额遗漏 purchases）已修复。

### 场景 4.2 — 有购烟记录时的单价逻辑（核心 bug）

**数据**：`profile=¥25/包, 20支/包(¥1.25/支)`。购烟 1 包 ¥30/包，20支/包 → 购烟价 ¥1.50/支。购烟后第 1 天记录 10 支（日志无快照）。购烟包尚未耗尽（只抽了 10 支 < 20 支）。

**两套价格逻辑对比**：

**A. DashboardViewModel.effectivePricePerCig**（用于今日节省）：
```
purchaseDay = 购烟当天
totalBought = 1 × 20 = 20
smokedSince = 10
10 < 20 → NOT exhausted → 使用购烟价: 30/20 = ¥1.50
todaySavings = max(0, 20-10) × 1.50 = ¥15.0
```

**B. UserProfile.moneySaved → perCigPrice**（用于累计已节省）：
```
purchaseExhaustionDate: totalBought=20, cumulative=10 → 10 < 20 → NOT exhausted
→ 返回 nil (exhaustionDate = nil)

perCigPrice:
  1. log.pricePerPackAtTime = 0 → skip
  2. exhaustionDate = nil → let exhaustion = exhaustionDate 失败 → skip
  3. 回退 profile 价格: 25/20 = ¥1.25
moneySaved = (20-10) × 1.25 = ¥12.5
```

**结果**：
| 显示位置 | 单价 | 今日/累计节省 |
|---------|------|-------------|
| 首页今日减量卡 | ¥1.50 | **¥15.0** |
| 首页已节省卡片 | ¥1.25 | **¥12.5** |
| 进度页已节省 | ¥1.25 | **¥12.5** |

**同一屏两个金额不一样**：减量卡说省了 ¥15.0，MoneySavedCard 说已省 ¥12.5。差 ¥2.5。

**根本原因**：`perCigPrice` 中的 `exhaustionDate` 逻辑是**反转**的：
- `purchaseExhaustionDate` 在**未耗尽**时返回 nil → perCigPrice 跳过购烟价 → 用 profile 价
- `purchaseExhaustionDate` 在**已耗尽**时才返回日期 → perCigPrice 才用购烟价

这正好与实际需求**相反**：用户正在消耗购烟包时应使用购烟价格；消耗完后额外抽的才应回退到 profile 价格。

**结论**：购烟价格的省钱计算逻辑反转。用户买了一包 ¥30 的烟，抽的时候 App 按 ¥25 算，抽完了反而按 ¥30 算。**这是数据正确性 bug。**

### 场景 4.3 — 购烟已耗尽

**数据**：同 4.2 但已抽 25 支（购烟包 20 支已耗尽 5 支）。

**perCigPrice 行为**：
- `purchaseExhaustionDate`：cumulative 在某天达到 20 → 返回该日期
- 耗尽日之前的日志：`logDate ∈ [purchaseDay, exhaustionDate]` → 购烟价 ¥1.50 ✓
- 耗尽日之后的日志：`logDate > exhaustionDate` → profile 价 ¥1.25 ✓

**结论**：已耗尽情况下逻辑正确。但问题在于：此时用户早已消耗完了购烟包，才开始用购烟价算之前的节省 —— 在此之前，同一批日志的节省金额是用 profile 价算的。**金额会突然跳变**。

---

## 功能 5: 目标

### 场景 5.1 — 目标"连续控烟 7 天"自动完成

**代码路径**：
```
GoalsView.checkCompletion()
→ vm.checkCompletion(goals:, streakDays: profile.actualStreakDays(logs:), moneySaved: ...)
→ if goal.targetMoneySaved > 0 { ... } else { achieved = streakDays >= goal.targetDays }
```

**触发时机**：
- `GoalsView.onAppear`
- `GoalsView.onChange(of: logs.count)` ← **每次记录保存后触发**
- `GoalsView.onChange(of: goals.count)`

**结论**：✅ 目标在 logs.count 变化时自动检查。但注意：`streakDays` 使用的是 `actualStreakDays`（lenient 模式），而非实际记录的连续控烟天数。

**关键问题**：如果用户 quitDate=30 天前，但只有 2 天记录（各有 10 支 < 20 基准），`actualStreakDays` = 30（lenient —— 无记录日不计入中断）。目标 "连续控烟 7 天" 会立即完成 —— 即使用户实际上只有 2 天有记录证据。

这与目标标题「连续控烟 7 天」的语义不符。用户期望的是"我真正连续 7 天控制住了"。

### 场景 5.2 — 金额目标"节省 ¥100"

**数据**：已省 ¥95（profile 价），今日少抽 5 支 → `5 × 1.25 = ¥6.25` → 累计 ¥101.25

**checkCompletion**：`moneySaved(logs:logs, purchases:purchases) = 101.25 ≥ 100` → `goal.isCompleted = true` ✅

**成就评估**：`profile.moneySaved(logs:logs, purchases:purchases) = 101.25 ≥ 100` → `money_100` 解锁 ✅

**结论**：✅ 目标完成和成就解锁使用相同的 moneySaved 方法，一致。

---

## 功能 6: 成就徽章

### 场景 6.1 — 连续 3 天低于基准，第 3 天保存后

**触发链**：
1. 用户在记录页保存第 3 天日志
2. `LoggingView.onSave` → `AchievementService.evaluateAndAward(profile:, logs:, purchases:, context:)`
3. `consecutiveDaysBelow`：从 today 往回，3 天均有 log 且 < baseline → 返回 3
4. `streak_3_days.requiredConsecutiveDaysBelow = 3 ≥ 3` → **立即解锁**

用户切到 Dashboard → `updateVM()` 再调用一次 `evaluateAndAward`，但 `unlockedIDs` 已包含 `streak_3_days` → 跳过。

**结论**：✅ 成就保存后立即解锁，不依赖进入首页。去重机制防止重复。

### 场景 6.2 — 解锁后 streak 中断

- `streak_3_days` 已在 CoreData 的 `UnlockedAchievement` 表中
- `evaluateAndAward` 的 guard `!unlockedIDs.contains(definition.id)` → 永远跳过
- 成就**永不消失** ✅

**结论**：✅ 已解锁成就永久保留，符合成就系统惯例。

### 场景 6.3 — 节省金额成就与购烟价

**代码**：`profile.moneySaved(logs: logs, purchases: purchases) >= required`
- purchases 参数已传入（M2 修复后）✅
- 但 `moneySaved` → `perCigPrice` 存在 4.2 中的反转 bug —— 购烟未耗尽时使用 profile 价格
- 所以成就的解锁条件可能被低估（购烟价 ¥1.50 vs profile 价 ¥1.25）

**结论**：成就金额评估受 perCigPrice bug 影响，与 Dashboard 显示有相同偏差。

---

## 功能 7: 一致性检查

### 场景 7.1 — 多视图金额一致性

所有视图调用 `profile.moneySaved(logs:logs, purchases:purchases)` 且传入相同的 purchases 参数。**方法调用一致** ✅。

但注意 `DashboardViewModel.updateReduction` 中的 `todaySavings` 使用 `effectivePricePerCig`（不同方法），与 `moneySaved` 可能产生不同单价 → 今日节省 vs 累计节省数字不一致（见场景 4.2）。

### 场景 7.2 — 首页 Streak vs 时间线 vs 成就 Streak 三角矛盾

| 维度 | 算法 | 无记录日行为 |
|------|------|------------|
| 首页 StreakCard | `actualStreakDays` | 算"低于基准"，继续计数 |
| 时间线里程碑 | `actualStreakDays` | 同上 |
| 成就徽章 | `consecutiveDaysBelow` | 算"中断"，归零 |

**具体矛盾场景**：quitDate=30天前，仅有 2 天日志（均<基准）
- 首页：「连续控烟 30 天」
- 时间线：「一个月突破」✅ 已解锁
- 成就页：只有 `streak_1_day` 徽章（2天 < 3天所需），没有 `streak_3_days`

用户看到「30 天控烟 + 一个月突破已解锁」但「三日勇士都没拿到」→ **严重困惑**。

---

## Issues

### Critical

- [C1] **场景 4.2 — perCigPrice 购烟价格逻辑反转：购烟未耗尽时使用 profile 价，耗尽后才使用购烟价**
  - 根因：`purchaseExhaustionDate` 在未耗尽时返回 nil → `perCigPrice` 的 `let exhaustion = exhaustionDate` 解包失败 → 跳过购烟价分支
  - 正确行为：正在消耗购烟包时应使用购烟价；耗尽后额外抽的才回退 profile 价
  - 影响：moneySaved 在购烟消耗期间低估节省金额，耗尽后突然跳变
  - `UserProfile.swift:105-113`（perCigPrice 的 exhaustion 解包条件）

### Major

- [M1] **场景 1.2/3.2/7.2 — Dashboard/Timeline 与 Achievements 对"连续控烟"使用不同定义**
  - Dashboard & Timeline 用 `actualStreakDays`（lenient：无记录=继续计数）
  - Achievements 用 `consecutiveDaysBelow`（strict：无记录=中断）
  - 导致同一用户看到 StreakCard 显示 N 天、Timeline 解锁到 N 天里程碑、但 Achievements 零徽章
  - `UserProfile.swift:59-76` vs `AchievementService.swift:61-81`

- [M2] **场景 5.1 — 目标自动完成使用 lenient streak，可在无实际行为下完成**
  - `GoalsView.checkCompletion` 使用 `actualStreakDays`
  - 用户 quitDate=30天前 + 零日志 → streak=30 → 目标"连续控烟 7 天"立即完成
  - 与目标标题语义矛盾（"连续控烟"暗示实际行为，非日历天数）
  - `GoalsView.swift:87-88`

- [M3] **场景 2.2 — "已节省"金额可显负数，用户体验困惑**
  - 超出基准时 `moneySaved` 扣减（`reduced = baseline - count` 可为负）
  - 首次记录即超标时：「已节省 **-¥6.3**」—— "节省"与负数语义冲突
  - 建议：将 UI 文案改为"累计差额"或在负数时特殊处理
  - `UserProfile.swift:82-83`, `DashboardView.swift:34-36`

- [M4] **场景 3.1/3.2 — milestoneUnlockDate 始终返回今天**
  - `profile.milestoneUnlockDate` 中的 `return cal.startOfDay(for: Date())` 硬编码返回今天
  - 无论里程碑实际何时达成，时间线页都显示"解锁于 [today]"
  - `UserProfile.swift:152`

- [M5] **场景 4.2 — 首页同日显示两个不同金额**
  - "今日用量"卡（todaySavings）：使用 `effectivePricePerCig` → 购烟未耗尽时用购烟价 ¥1.50 → 显示 ¥15.0
  - "已节省"卡（moneySaved）：使用 `perCigPrice` → 购烟未耗尽时用 profile 价 ¥1.25 → 显示 ¥12.5
  - 差异在购烟价 ≠ profile 价时出现，用户不理解为何同一天有两个不同数字
  - `DashboardViewModel.swift:80-81` vs `DashboardViewModel.swift:28` → `UserProfile.swift:95-113`

- [M6] **场景 4.1/7.1 — Widget 在仅使用记录 Tab 时不更新**
  - `writeWidgetData` 仅在 `DashboardView.updateVM()` 中调用
  - 用户在 Logging Tab 保存后 Widget 仍显示旧数据，直到切到 Dashboard 或下次定时刷新（1小时）
  - `LoggingView.swift:25-41` — onSave 中缺少 widget 更新调用

### Minor

- [m1] **场景 1.1 — 引导完成首日即显示 streak=1**
  - 用户未记录任何日志，首页显示"连续控烟 1 天"
  - `actualStreakDays` 对无记录日不做中断
  - 对新手用户可能产生"已完成一天"的虚假成就感
  - `UserProfile.swift:59-76`

- [m2] **场景 3.1 — 里程碑进度环在刚完成一个里程碑后显示 0%**
  - streak=7 → 刚解锁"一周控烟" → 下一个"两周里程碑"进度 = `(7-7)/(14-7) = 0%`
  - 用户看到进度环归零，感觉"一切重新开始"
  - `DashboardViewModel.swift:36-40`

- [m3] **场景 4.2 — totalSpentOnSmokes 不使用购烟价**
  - "迄今实际花费"使用 `log.pricePerPackAtTime` 或 `profile.pricePerPack`，不查购烟记录
  - 用户买了 ¥50/包的高价烟，显示的实际花费仍按 ¥25/包算
  - `DashboardViewModel.swift:107-111`

---

## Coder Response
<!-- Coder 在修复后填写此节；Reviewer 初次产出时省略 -->

## Escalate

- [ESCALATE] **Dashboard/Timeline strek 定义选择** — 当前 `actualStreakDays`（lenient）和 `consecutiveDaysBelow`（strict）并存，在多个页面间产生不一致。需要产品决策：
  1. 统一使用 strict 模式（无记录=中断）→ 更诚实但用户数据不完整时体验差
  2. 统一使用 lenient 模式（无记录=算成功）→ 更激励但有"虚假进度"风险
  3. 保持差异化但明确告知用户（如 StreakCard 标注"含未记录日"、成就页说明"需每日记录"）
  当前推荐的折衷：StreakCard 和 Timeline 保留 lenient（正向激励），但 Goals 改用 strict（目标应反映真实行为）。

- [ESCALATE] **"已节省"负数显示** — 超出基准导致钱数扣减在数学上正确，但"节省"呈现负数违反自然语言直觉。需要产品决定：
  1. 保持当前行为（节省可负）
  2. 负数时显示"多花了 ¥XX"而非"节省 -¥XX"
  3. 将 UI 概念拆分为"少抽节省"和"多抽支出"，分开显示
