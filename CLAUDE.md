# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

- **Build**: Open `SmokeFree/SmokeFree/SmokeFree.xcodeproj` in Xcode 15+, select iPhone 15 Pro (iOS 17.5) simulator, press `⌘R`
- **Run all tests**: `⌘U` or Product → Test
- **Run single test**: Click the ▶ icon next to the test method, or press `⌃⌥⌘U` with cursor inside the test
- **Test files (32 tests total)**: `UserProfileTests`, `DashboardViewModelTests`, `AchievementServiceTests`, `GoalsViewModelTests`
- **Clean build**: `⇧⌘K` before re-running if Widget or HealthKit behaves oddly
- **Xcode manual setup required** (after cloning, before first build):
  1. Add HealthKit capability to main Target (Signing & Capabilities → + Capability → HealthKit)
  2. Create Widget Extension target named `SmokeFreeWidget` (File → New → Target → Widget Extension, uncheck Live Activity and Configuration App Intent)
  3. Add App Groups capability (`group.com.smokefree.app`) to both main and widget targets

## Architecture (MVVM + SwiftData + CloudKit)

### Navigation
```
ContentView
├── OnboardingContainerView (first launch, 4 screens)
│   ├── WelcomeView → SmokingHabitsView → QuitDateView → NotificationsPermissionView
└── MainTabView (5 tabs)
    ├── Tab 1 - 首页 (DashboardView) — streak cards, reduction progress ring, milestones
    ├── Tab 2 - 记录 (LoggingView) — daily log + history list (30 days)
    ├── Tab 3 - 进度 (ProgressTabView) — charts, timeline, achievements
    ├── Tab 4 - 目标 (GoalsView) — goal CRUD with auto-completion
    └── Tab 5 - 购烟 (PurchasesView) — purchase records grouped by month
```

### Data Models (SwiftData `@Model`, all flat — no `@Relationship`)
- **UserProfile**: quitDate, cigarettesPerDayBefore (baseline), pricePerPack, cigarettesPerPack, currencyCode, goalAmount/Name. Computed: streakDays, actualStreakDays(logs:), moneySaved(logs:)
- **SmokingLog**: date, count, notes. Snapshots baselineAtTime/pricePerPackAtTime/cigarettesPerPackAtTime at save time
- **PurchaseRecord**: date, brand, quantity, pricePerPack, totalCost
- **Goal**: title, reward, targetDays, targetMoneySaved, isCompleted, sortOrder
- **UnlockedAchievement**: badgeID (matches AchievementDefinition.id), unlockedAt, isNewlySeen

### ViewModels (iOS 17 `@Observable`, not ObservableObject)
Injected via `.environment(vm)`. Key ones:
- **DashboardViewModel**: streak, moneySaved, nextMilestone, reduction progress, widget data bridge
- **LoggingViewModel**: todayCount CRUD, recentLogs filtering, feedbackMessage generation
- **GoalsViewModel**: goal CRUD, auto-complete, form validation
- **AchievementsViewModel / ChartsViewModel / HealthTimelineViewModel / PurchaseViewModel / OnboardingViewModel**

### Services
- **AchievementService**: Static pure functions — `evaluateAndAward(profile:logs:context:)` checks 4 badge types (streak days, consecutive days below baseline, reduction %, money saved). `consecutiveDaysBelow` is strict (no log = break). `sevenDayAverage` uses 0 for missing days
- **HealthKitService**: Swift `actor` — writes mindful session to Health app daily. Call `requestAuthorization()` then `recordSmokeFreeToday()`
- **NotificationService**: Daily 21:00 reminder + milestone celebration push

### Key Architectural Decisions
1. **`@Observable` over `ObservableObject`** — iOS 17 Observation framework, no `@Published` needed
2. **No `@Relationship` in SwiftData models** — CloudKit doesn't handle relationships well; use string IDs for cross-model references
3. **AppGroup UserDefaults for Widget data** — not SwiftData, because widget extension runs in separate process
4. **Money saved is log-based** — `Σ max(0, baseline - log.count) × perCigPrice`, not calendar-day estimation. Only counts days with actual records
5. **Two streak calculations**: `actualStreakDays` (lenient — missing days count as below-baseline, for dashboard) vs `consecutiveDaysBelow` (strict — missing = break, for achievements)
6. **SmokingLog snapshots** — baselineAtTime/pricePerPackAtTime/cigarettesPerPackAtTime are captured when log is saved, so historical records aren't affected by later profile changes
7. **Static config in AppConfig.swift** — health milestones, achievement definitions, cost comparison presets all defined as static arrays
8. **All `@Model` properties must have defaults or be Optional** — CloudKit requirement

### Significant Config Details
- Health milestones defined in AppConfig (1 day → 1 year)
- Achievement definitions: 7 streak badges (1d–365d), 2 reduction badges (50%, 75%), 2 money badges (¥100, ¥500)
- Cost comparison presets: iPhone 16 (¥6999) to Tesla Model 3 (¥239900)
- Simulator CloudKit disabled: `#if targetEnvironment(simulator)` → `ModelConfiguration.CloudKitDatabase.none`
