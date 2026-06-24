# SmokeFree — 控烟助手

一款帮助用户逐步减少吸烟量的 iOS 原生应用。通过每日记录、减量激励、目标管理和健康里程碑追踪，让控烟过程可量化、有反馈。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![iOS 15.8+](https://img.shields.io/badge/iOS-15.8%2B-blue)](https://developer.apple.com/ios/)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)

## 功能

- **每日记录** — 记录每天吸烟支数，与基准对比，保存后即时显示激励反馈
- **减量进度** — 首页进度环显示今日用量 vs 基准，等价物换算（矿泉水、奶茶等）
- **节省金额** — 实际少抽支数 × 单支价格累计，支持负数（超出基准时扣减）
- **购烟记录** — 记录购烟品牌/数量/价格，节省金额自动采用最近购烟实价
- **目标管理** — 设定控烟天数或金额目标，达成后自动完成
- **成就徽章** — 11 枚成就（连续控烟、减量幅度、节省金额）
- **健康里程碑时间线** — 从控烟第一天到整整一年的里程碑进度
- **趋势图表** — 近 7/30 天烟量和支出柱状图
- **桌面小组件** — 小/中尺寸，显示控烟天数和节省金额
- **数据导出/导入** — 备份为 CSV + JSON，支持跨设备恢复
- **iCloud 同步** — CloudKit 多设备同步

## 技术栈

| 项目 | 内容 |
|------|------|
| 语言 | Swift 5.9 |
| UI | SwiftUI |
| 持久化 | Core Data + CloudKit (`NSPersistentCloudKitContainer`) |
| 图表 | 手绘 SwiftUI（`GeometryReader` + `Rectangle`） |
| 健康 | HealthKit |
| 小组件 | WidgetKit + AppGroup UserDefaults |
| 最低系统 | **iOS 15.8** |
| 架构 | MVVM（`ObservableObject` + `@Published`） |

## 快速开始

### 环境要求
- Xcode 15+
- iOS 15.8+ 模拟器或真机

### 步骤

```bash
git clone https://github.com/chncaesar/smoke_free.git
cd smoke_free
```

1. 打开 `SmokeFree/SmokeFree/SmokeFree.xcodeproj`
2. 复制本地配置文件：
   ```bash
   cp SmokeFree/SmokeFree/LocalConfig.xcconfig.example SmokeFree/SmokeFree/LocalConfig.xcconfig
   ```
   然后在 `LocalConfig.xcconfig` 中填入你的 Apple Developer Team ID
3. 手动添加以下能力（Xcode 无法通过代码配置）：
   - **HealthKit**：TARGETS → SmokeFree → Signing & Capabilities → + Capability → HealthKit
   - **Widget Extension**：File → New → Target → Widget Extension，名称填 `SmokeFreeWidget`，取消勾选 Live Activity 和 Configuration App Intent
   - **App Groups**：主 Target 和 Widget Target 均添加 `group.com.smokefree.app`
4. 选择模拟器，按 `⌘R` 运行

## 运行测试

```
⌘U
```

4 个测试文件，测试核心业务逻辑（streak 计算、moneySaved、成就评估、目标完成）。

## 项目结构

```
SmokeFree/SmokeFree/SmokeFree/
├── SmokeFreeApp.swift         # App 入口，NSPersistentCloudKitContainer 初始化
├── AppConfig.swift            # 静态配置：里程碑、成就定义、等价物预设
├── Models/                    # Core Data NSManagedObject 子类（5个）
│   ├── UserProfile.swift      # 用户档案 + streak/moneySaved 计算
│   ├── SmokingLog.swift       # 每日记录（含价格快照字段）
│   ├── PurchaseRecord.swift   # 购烟记录
│   ├── Goal.swift             # 目标与奖励
│   └── UnlockedAchievement.swift
├── ViewModels/                # ObservableObject ViewModel（8个）
├── Views/
│   ├── Onboarding/            # 4步引导流程
│   ├── Dashboard/             # 首页：streak、减量进度、节省金额、里程碑
│   ├── Logging/               # 每日记录 + 历史列表
│   ├── Purchases/             # 购烟记录
│   ├── Goals/                 # 目标 CRUD
│   ├── Charts/                # 趋势图表（手绘柱状图）
│   ├── HealthTimeline/        # 健康里程碑时间线
│   ├── Achievements/          # 成就徽章宫格
│   └── Shared/                # CardView, ProgressRingView
├── Services/
│   ├── AchievementService.swift
│   ├── HealthKitService.swift
│   ├── NotificationService.swift
│   ├── DataExportService.swift
│   └── DataImportService.swift
└── Widget/                    # 小组件 UI + Provider
```

## 核心逻辑说明

### 每支烟价格（三级优先）
1. 日志快照（记录时保存的价格）
2. 最近购烟记录价格（当这批烟还未抽完时）
3. 个人资料设置价格（兜底）

### Streak 计算
- **没记录 = 0 支 = 低于基准**，streak 继续（宽松模式）
- 记录了且支数 ≥ 基准 → streak 中断

### 节省金额
```
moneySaved = Σ (baseline - log.count) × perCigPrice
```
可为负数（超出基准时扣减），首页显示"已超额"红字。

## License

[MIT](LICENSE)
