# SmokeFree — 控烟助手

一款帮助用户逐步减少吸烟量的 iOS 应用。通过每日记录、减量激励、目标管理和健康恢复追踪，让控烟过程可量化、有反馈。

## 技术栈

- **语言/框架：** Swift, SwiftUI
- **数据持久化：** SwiftData + CloudKit（iCloud 多设备同步）
- **图表：** Swift Charts
- **健康集成：** HealthKit（写入正念记录）
- **小组件：** WidgetKit（AppGroup UserDefaults 数据桥接）
- **最低系统：** iOS 17+
- **架构：** MVVM（iOS 17 `@Observable`）

## 快速开始

1. 用 Xcode 15+ 打开 `SmokeFree/SmokeFree/SmokeFree.xcodeproj`
2. 选择 iPhone 15 Pro (iOS 17.5) 模拟器
3. `⌘R` 运行

### 首次运行前需手动配置

**HealthKit 能力：** 项目 TARGETS → SmokeFree → Signing & Capabilities → + Capability → HealthKit

**Widget Extension Target：**
1. File → New → Target → Widget Extension
2. Product Name 填 `SmokeFreeWidget`
3. 取消勾选 "Include Live Activity" 和 "Include Configuration App Intent"
4. 将 `SmokeFree/Widget/` 下的两个 `.swift` 文件加入该 Target（并从主 Target 移除勾选）

**App Groups：** 主 Target 和 Widget Target 均添加 App Groups 能力，ID 填 `group.com.smokefree.app`

## 运行测试

- **全部测试：** `⌘U`
- **单个测试：** 点击测试方法旁的 ▶ 图标，或光标置于方法内按 `⌃⌥⌘U`
- **4 个测试文件**，共 32 个用例

## 项目结构

```
SmokeFree/SmokeFree/SmokeFree/
├── SmokeFreeApp.swift         # App 入口，ModelContainer 初始化
├── AppConfig.swift            # 静态配置：里程碑、成就定义、等价物
├── Models/                    # SwiftData 模型（5个）
├── ViewModels/                # @Observable ViewModel（8个）
├── Views/                     # 视图层
│   ├── Onboarding/            # 4步引导流程
│   ├── Dashboard/             # 首页：连续天数、减量进度、节省金额
│   ├── Logging/               # 每日记录 + 历史列表
│   ├── Purchases/             # 购烟记录
│   ├── Goals/                 # 目标 CRUD
│   ├── Charts/                # 烟量/支出趋势图表
│   ├── HealthTimeline/        # 健康恢复里程碑时间线
│   ├── Achievements/          # 成就徽章宫格
│   └── Shared/                # CardView, ProgressRingView
├── Services/                  # HealthKitService, NotificationService, AchievementService
└── Widget/                    # 小组件 UI + Provider
```
