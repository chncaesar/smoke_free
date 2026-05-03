# SmokeFree — 模拟器测试文档

## 目录

1. [前置条件](#1-前置条件)
2. [Xcode 手动配置](#2-xcode-手动配置)
3. [首次运行与引导流程](#3-首次运行与引导流程)
4. [各 Tab 功能测试](#4-各-tab-功能测试)
5. [减量激励专项测试](#5-减量激励专项测试)
6. [成就徽章触发指南](#6-成就徽章触发指南)
7. [通知测试](#7-通知测试)
8. [Widget 测试](#8-widget-测试)
9. [单元测试](#9-单元测试)
10. [常见问题](#10-常见问题)

---

## 1. 前置条件

| 项目 | 要求 |
|------|------|
| Xcode | 15.0 或更高 |
| 模拟器 | iPhone 15 / iOS 17.0+ |
| Apple ID | 需登录 Xcode（用于 CloudKit 沙盒） |

推荐模拟器：**iPhone 15 Pro（iOS 17.5）**

---

## 2. Xcode 手动配置

> 代码已就绪，但以下三项需在 Xcode 中手动开启，否则 HealthKit 和 Widget 会崩溃。

### 2.1 HealthKit 能力

1. Xcode 左侧文件树顶部，点击**蓝色图标的 `SmokeFree` 项目文件**
2. 中间区域 **TARGETS** 列表 → 点击 `SmokeFree`
3. 右侧标签栏点击 **Signing & Capabilities**
4. 左上角点击 **+ Capability** → 搜索 `HealthKit` → 双击添加

### 2.2 Widget Extension Target

1. **File → New → Target** → 选 **Widget Extension**
2. **Product Name**：`SmokeFreeWidget`
3. 取消勾选 "Include Live Activity" 和 "Include Configuration App Intent"
4. 将 `SmokeFree/Widget/` 下的两个文件加入该 Target：
   - `SmokeFreeWidget.swift`（同时**移除**主 Target 的勾选）
   - `WidgetProvider.swift`（同时**移除**主 Target 的勾选）

### 2.3 App Groups

主 Target 和 Widget Target **各做一次**，步骤相同：

1. TARGETS → 选择对应 Target → **Signing & Capabilities**
2. **+ Capability → App Groups**
3. App Groups 栏里点击 `+`，填入：`group.com.smokefree.app`
4. 两个 Target 填写的 ID 必须**完全一致**（复制粘贴，勿手打）

---

## 3. 首次运行与引导流程

```
⌘R → 选择 iPhone 15 Pro 模拟器 → 运行
```

### 引导步骤验证

| 步骤 | 操作 | 预期结果 |
|------|------|---------|
| 欢迎页 | 可填可不填姓名 | 点"下一步"正常跳转 |
| 用烟习惯 | 设置每天 **20 支**，每包 **¥25**，每包 **20 支** | 下一步按钮可点击 |
| 戒烟日期 | 选择**今天**或过去某天 | 日期不能选未来 |
| 通知权限 | 点"开启通知权限" | 弹出系统权限弹窗，点"允许" |
| 完成 | 点"开始我的戒烟之旅" | 进入主界面 Tab 1 |

### 重置引导（重新测试）

模拟器菜单：**Device → Erase All Content and Settings**

或在 Xcode 控制台运行（需在 app 启动前）：
```
UserDefaults.standard.removeObject(forKey: "onboardingComplete")
```

---

## 4. 各 Tab 功能测试

### Tab 1 — 首页

| 验证项 | 操作 | 预期结果 |
|--------|------|---------|
| 连续天数 | 查看卡片 | 显示从戒烟日期至今的天数 |
| 减量进度卡 | 查看 | 显示"尚未记录"，进度环为空 |
| 节省金额 | 查看 | 根据基准用量自动计算 |
| 健康里程碑 | 查看 | 显示下个未解锁里程碑及剩余时间 |

### Tab 2 — 记录

| 验证项 | 操作 | 预期结果 |
|--------|------|---------|
| 今日记录 | Stepper 调到 **8 支** → 点"保存" | 粉色 banner 出现："比基准少了 12 支（减少 60%），不错！" |
| 无烟记录 | Stepper 调到 **0** → 保存 | 绿色 checkmark + banner："今天完全无烟！继续保持！" |
| 超出基准 | Stepper 调到 **25 支** → 保存 | banner："今天多了一点，明天可以更好！" |
| 历史列表 | 保存后查看 | 今天记录出现在"最近 30 天"列表 |
| 删除记录 | 左滑历史行 | 删除成功 |

### Tab 3 — 进度

| 验证项 | 操作 | 预期结果 |
|--------|------|---------|
| 节省目标 | 点"设定节省目标" → 输入 **500** → 保存 | 进度条出现，显示"距目标 ¥500 还差 ¥XXX" |
| 修改目标 | 点"修改" → 改为 **100** | 进度更新 |
| 清除目标 | 再次点"修改" → 点"清除目标" | 恢复"设定节省目标"按钮 |
| 等价物显示 | 节省金额超过 ¥35 | 显示"够买 1 顿麦当劳" |
| 趋势图表 | 点进"趋势图表" | 显示柱状图 + "日均 X 支 / 基准 20 支 / ↓ Z%" |
| 图表切换 | 切换"近 7 天 / 近 30 天" | 图表数据更新 |

### Tab 4 — 目标

| 验证项 | 操作 | 预期结果 |
|--------|------|---------|
| 添加目标 | 点 `+` → 标题"坚持一周"，奖励"买本书"，7天 → 保存 | 出现在"进行中" |
| 表单验证 | 清空标题直接保存 | 保存按钮不可点击 |
| 自动完成 | 设一个 0 天目标（需在代码里临时改） | 立即移入"已完成" |

### Tab 5 — 购烟

| 验证项 | 操作 | 预期结果 |
|--------|------|---------|
| 添加记录 | 点 `+` → 填写品牌、数量、价格 | 出现在月度分组列表 |
| 月度统计 | 添加多条记录 | 顶部"本月 ¥XXX"数字更新 |
| 删除 | 左滑 | 删除成功，金额重新计算 |

---

## 5. 减量激励专项测试

### 5.1 首页减量进度卡

1. 进入 Tab 2，将今日用量设为 **10 支**（基准 20 支）→ 保存
2. 切回 Tab 1

**预期：**
- 进度环填充 50%（橙色）
- 显示"10 支"
- 副文字："比基准少了 10 支（减少 50%）"
- 绿色文字："省了 ¥6.25，相当于 3 瓶矿泉水"（具体取决于烟价）

### 5.2 等价物边界测试

修改引导里的烟价来控制每支价格，验证不同等价物显示：

| 今日少抽 | 单支价格 | 今日节省 | 预期等价物 |
|---------|---------|---------|-----------|
| 5 支 | ¥1.25 | ¥6.25 | 3 瓶矿泉水 |
| 10 支 | ¥1.25 | ¥12.50 | 4 瓶矿泉水 |
| 15 支 | ¥2.00 | ¥30.00 | 1 个包子（不够奶茶） |
| 20 支 | ¥2.00 | ¥40.00 | 1 顿麦当劳 |

### 5.3 记录后反馈消息逻辑

| 场景 | 今日 | 昨日 | 基准 | 预期消息 |
|------|------|------|------|---------|
| 完全无烟 | 0 | - | 20 | "今天完全无烟！继续保持！" |
| 比昨天少 | 8 | 12 | 20 | "比昨天少了 4 支，继续加油！" |
| 比昨天多但低于基准 | 14 | 10 | 20 | "比基准少了 6 支（减少 30%），不错！" |
| 与基准持平 | 20 | - | 20 | "继续努力，明天再少一支！" |
| 超出基准 | 25 | - | 20 | "今天多了一点，明天可以更好！" |

> **模拟昨日数据：** 先在昨天的模拟器日期记录（见下方「调整系统时间」），或直接在单元测试里验证。

---

## 6. 成就徽章触发指南

> 连续天数类徽章需要真实时间或调整系统时间。减量类徽章可以当天触发。

### 6.1 当天可触发的徽章

**reduction_first_day（迈出第一步）**
1. 记录今日用量 < 20 支
2. 切到 Tab 1 → 首页自动评估
3. 进入"成就徽章"页 → 应解锁

### 6.2 使用模拟器时间调整触发多天徽章

1. **模拟器菜单 → Device → Override Status Bar → 修改时间**
   - 或：Mac 系统时间设为 N 天前，重新运行 App

2. 按以下顺序操作：

```
第1天：记录 < 20 支 → 保存
第2天：调时间到明天 → 重启App → 记录 < 20 支 → 保存
第3天：调时间到后天 → 重启App → 记录 < 20 支 → 保存
→ 首页刷新 → "坚持三天"徽章解锁
```

### 6.3 减量百分比徽章（reduction_half / reduction_quarter）

**更快的方法：用单元测试验证逻辑，不需要真实等待**

```
⌘U → 运行 AchievementServiceTests
→ awards_reductionHalf_whenSevenDayAvgBelowHalf ✓
```

如需在模拟器内触发：
1. 连续 7 天记录用量 ≤ 10 支（基准 20 支的 50%）
2. 第 7 天在首页刷新后解锁"减半达人"

---

## 7. 通知测试

### 7.1 验证每日提醒（21:00）

模拟器不支持真实等待，使用以下方法立即触发：

1. Xcode 菜单：**Debug → Simulate Push Notification**
2. 或使用 `notificationd` 命令（模拟器终端）：

```bash
xcrun simctl push <device_id> com.yourapp.smokefree notification.json
```

`notification.json`：
```json
{
  "aps": {
    "alert": {
      "title": "记录今天的情况",
      "body": "别忘了记录今天的烟量，坚持就是胜利！"
    },
    "sound": "default"
  }
}
```

### 7.2 验证权限已授予

在模拟器 **Settings → Notifications → SmokeFree** 中确认：
- 允许通知：✓
- 横幅：✓
- 声音：✓

### 7.3 查看已排期的通知（调试）

在 App 代码里临时添加（测试完删除）：

```swift
UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
    requests.forEach { print($0.identifier, $0.trigger ?? "no trigger") }
}
```

---

## 8. Widget 测试

> 需先完成 2.2 和 2.3 的配置。

### 8.1 添加 Widget 到模拟器主屏幕

1. 模拟器主屏幕长按空白处 → 进入抖动模式
2. 左上角 `+` → 搜索 `SmokeFree`
3. 选择小尺寸或中尺寸 → 添加

### 8.2 验证 Widget 数据

| 步骤 | 操作 | 预期 |
|------|------|------|
| 初始状态 | 查看 Widget | 显示"0 天无烟"，金额为 0 |
| 切回 App | Tab 1 首页停留 1 秒 | Widget 内容在约 60 秒内更新（模拟器延迟较长） |
| 强制刷新 | 重启模拟器 | Widget 立即读取最新 AppGroup 数据 |

### 8.3 调试 Widget 数据是否写入

在 Xcode 控制台输出 AppGroup UserDefaults：

```swift
let d = UserDefaults(suiteName: "group.com.smokefree.app")
print("streakDays:", d?.integer(forKey: "widget_streakDays") ?? "nil")
print("moneySaved:", d?.double(forKey: "widget_moneySaved") ?? "nil")
```

---

## 9. 单元测试

### 9.1 运行全部测试

```
⌘U
```

或指定 Target：**Product → Test**

### 9.2 测试文件说明

| 文件 | 覆盖内容 | 用例数 |
|------|---------|-------|
| `UserProfileTests` | streakDays、moneySaved 计算 | 6 |
| `DashboardViewModelTests` | 里程碑进度、时间格式化、金额格式化 | 7 |
| `AchievementServiceTests` | 成就颁发逻辑（含减量徽章） | 10 |
| `GoalsViewModelTests` | 目标完成、排序、表单验证 | 9 |

**合计 32 个测试用例，全部应为绿色。**

### 9.3 单独运行某个用例

点击测试文件左侧的 ▶ 图标，或：

```
⌃⌥⌘U  →  运行光标所在的单个测试
```

---

## 10. 常见问题

### App 启动崩溃（HealthKit）
**原因：** 未添加 HealthKit Capability
**解决：** 按 2.1 步骤添加，或在 `DashboardView` 里临时注释掉 `HealthKitService.shared.recordSmokeFreeToday()`

### Widget 不显示或显示占位数据
**原因：** AppGroup ID 不一致，或 Widget Target 未正确配置
**解决：**
1. 检查主 Target 和 Widget Target 的 App Groups 配置，确保 ID 完全相同
2. Clean Build（⇧⌘K）后重新运行

### CloudKit 同步不工作（模拟器）
**说明：** CloudKit 在模拟器上需要登录 iCloud 账号
模拟器：**Settings → Sign in to your iPhone** → 用测试 Apple ID 登录

### 通知权限弹窗不出现
**原因：** 模拟器已记录拒绝状态
**解决：** Erase All Content and Settings，或在 Settings → Notifications → SmokeFree 手动开启

### 减量进度卡显示"设定基准用量后显示"
**原因：** `cigarettesPerDayBefore == 0`，引导时未正确填写
**解决：** 重置引导，在"用烟习惯"页确保每日支数 > 0
