# CLAUDE.md

This file provides guidance to AI coding assistants when working with this repository.

## Build & Test

- **Build**: Open `SmokeFree/SmokeFree/SmokeFree.xcodeproj` in Xcode 15+, select iPhone 16 Pro (iOS 18.6) simulator, press `⌘R`
- **Run all tests**: `⌘U` or Product → Test
- **Run single test**: Click the ▶ icon next to the test method, or press `⌃⌥⌘U` with cursor inside the test
- **Test files**: `UserProfileTests`, `DashboardViewModelTests`, `AchievementServiceTests`, `GoalsViewModelTests`
- **Clean build**: `⇧⌘K` before re-running if Widget or HealthKit behaves oddly
- **Xcode manual setup required** (after cloning, before first build):
  1. Add HealthKit capability to main Target (Signing & Capabilities → + Capability → HealthKit)
  2. Create Widget Extension target named `SmokeFreeWidget` (File → New → Target → Widget Extension, uncheck Live Activity and Configuration App Intent)
  3. Add App Groups capability (`group.com.smokefree.app`) to both main and widget targets
  4. Copy `LocalConfig.xcconfig.example` → `LocalConfig.xcconfig` and fill in your Apple Developer Team ID

## Architecture (MVVM + Core Data + CloudKit)

### Navigation
```
ContentView
├── OnboardingContainerView (first launch, 4 screens)
│   ├── WelcomeView → SmokingHabitsView → QuitDateView → NotificationsPermissionView
└── MainTabView (5 tabs)
    ├── Tab 1 - 首页 (DashboardView) — streak, milestone progress, savings, cost card
    ├── Tab 2 - 记录 (LoggingView) — daily log + history list (30 days)
    ├── Tab 3 - 进度 (ProgressTabView) — charts, timeline, achievements, import
    ├── Tab 4 - 目标 (GoalsView) — goal CRUD with auto-completion
    └── Tab 5 - 购烟 (PurchasesView) — purchase records grouped by month
```

### Data Models (Core Data `NSManagedObject`, programmatic model in `PersistenceController`)
- **UserProfile**: quitDate, cigarettesPerDayBefore (baseline), pricePerPack, cigarettesPerPack, currencyCode, goalAmount/Name. Computed: streakDays, actualStreakDays(logs:), moneySaved(logs:purchases:)
- **SmokingLog**: date, count, notes. Snapshots baselineAtTime/pricePerPackAtTime/cigarettesPerPackAtTime (Int32/Double, 0 = not set)
- **PurchaseRecord**: date, brand, quantity, pricePerPack, totalCost
- **Goal**: title, reward, targetDays, targetMoneySaved (Double, 0 = not set), isCompleted, sortOrder
- **UnlockedAchievement**: badgeID (matches AchievementDefinition.id), unlockedAt, isNewlySeen

**Core Data rules**: All scalar properties (Int32, Double, Bool) are non-optional; 0/0.0/false = "not set". Use `context.save()` after every write. Core Data model is created programmatically in `PersistenceController.model`.

### ViewModels (`ObservableObject` + `@Published`)
Created as `@StateObject` in owning Views. Key ones:
- **DashboardViewModel**: streak, moneySaved, nextMilestone, reduction progress, widget data bridge, `effectivePricePerCig`
- **LoggingViewModel**: todayCount CRUD, recentLogs filtering, feedbackMessage generation
- **GoalsViewModel**: goal CRUD, auto-complete, form validation
- **AchievementsViewModel / ChartsViewModel / HealthTimelineViewModel / PurchaseViewModel / OnboardingViewModel**

### Services
- **AchievementService**: Static — `evaluateAndAward(profile:logs:purchases:context:)`. `consecutiveDaysBelow` is lenient (no log = 0 cigs = below baseline). `sevenDayAverage` uses 0 for missing days.
- **HealthKitService**: Swift `actor` — writes mindful session when today's log count == 0
- **NotificationService**: Daily 21:00 reminder (single-shot, rescheduled after logging); milestone push on streak increase (UserDefaults dedup)
- **DataExportService**: Exports all data as CSV + JSON to temp directory
- **DataImportService**: Imports from JSON with dedup logic per entity type

### Key Architectural Decisions
1. **Core Data over SwiftData** — iOS 15.8 minimum deployment target; `NSPersistentCloudKitContainer` for CloudKit sync
2. **Programmatic Core Data model** — no `.xcdatamodeld` file; model defined in `PersistenceController.model` static var
3. **No `@Relationship`** — CloudKit reliability; cross-model references via string IDs
4. **AppGroup UserDefaults for Widget** — widget extension runs in separate process
5. **Three-level price priority** — snapshot > latest purchase (while unconsumed) > profile default; `purchaseExhaustionDate` returns `Date.distantFuture` when purchase not yet exhausted
6. **Unified lenient streak** — both `actualStreakDays` and `consecutiveDaysBelow` treat no-log as 0 cigs (below baseline); no record = missed logging, not relapse
7. **moneySaved allows negative** — exceeding baseline reduces total savings; UI shows "已超额" in red when negative
8. **Milestone unlock date** — `today - (streakDays - requiredDays)` days ago; no complex log walking needed
9. **context.save() after every write** — Core Data requires explicit save; also saves on `scenePhase == .background`

### Significant Config Details
- Health milestones: `AppConfig.healthMilestones` — uses `requiredStreakDays` (not time offsets)
- Achievement definitions: 7 streak badges, 2 reduction badges (50%, 75% of baseline), 2 money badges (¥100, ¥500)
- Cost comparison presets: iPhone 16 (¥6999) to Tesla Model 3 (¥239900)
- Simulator CloudKit disabled: `#if targetEnvironment(simulator)` sets `cloudKitContainerOptions = nil`
- CloudKit container: `iCloud.com.smokefree.app`
- App Group: `group.com.smokefree.app`
