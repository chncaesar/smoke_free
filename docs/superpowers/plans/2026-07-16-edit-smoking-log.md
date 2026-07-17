# Edit Smoking Log Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users edit the count and notes of an existing historical smoking record without changing its date.

**Architecture:** Reuse the existing Logging tab data flow: historical rows select a `SmokingLog`, a small sheet edits local state, and `LoggingViewModel` saves the updated count and notes to Core Data. No schema change is needed because `SmokingLog` already stores `count` and `notes`, and `SmokingLog.changeToken` already includes both fields for downstream refresh.

**Tech Stack:** SwiftUI, Core Data, Swift Testing, existing MVVM classes.

## Global Constraints

- Do not modify `SmokingLog.date`.
- Do not create a new record when editing history; update the selected record only.
- Keep snapshot fields (`baselineAtTime`, `pricePerPackAtTime`, `cigarettesPerPackAtTime`) unchanged.
- Keep the UI consistent with existing sheet forms using `NavigationView`, `Form`, `取消`, and `保存`.
- Run local tests and `fvm flutter analyze` is not applicable because this is an iOS Swift project; use Xcode CLI tests/build where available.

---

### Task 1: ViewModel Update API

**Files:**
- Modify: `SmokeFree/SmokeFree/SmokeFree/ViewModels/LoggingViewModel.swift`
- Test: `SmokeFree/SmokeFreeTests/LoggingViewModelTests.swift`

**Interfaces:**
- Produces: `func updateLog(_ log: SmokingLog, count: Int, notes: String, context: NSManagedObjectContext)`
- Consumes: existing `SmokingLog` Core Data model.

- [ ] **Step 1: Write the failing test**

Add a Swift Testing test that creates a `SmokingLog`, calls `updateLog`, and verifies the same object has updated count and notes.

- [ ] **Step 2: Run the targeted test**

Run the project tests for `LoggingViewModelTests` and expect failure because `updateLog` does not exist yet.

- [ ] **Step 3: Implement the minimal save API**

Set `log.count`, trim notes to nil when empty, and call `context.save()`.

- [ ] **Step 4: Run the targeted test again**

Expect the new test to pass.

### Task 2: Historical Edit Sheet

**Files:**
- Modify: `SmokeFree/SmokeFree/SmokeFree/Views/Logging/LoggingView.swift`

**Interfaces:**
- Consumes: `LoggingViewModel.updateLog(_:count:notes:context:)`
- Produces: `EditSmokingLogView`, a private SwiftUI sheet view scoped to the Logging screen.

- [ ] **Step 1: Add selected-log state**

Store the currently selected `SmokingLog?` in `LoggingView`.

- [ ] **Step 2: Make historical rows tappable**

Wrap each row in a `Button` that sets the selected log while preserving the existing row layout and delete behavior.

- [ ] **Step 3: Add the edit sheet**

Present `EditSmokingLogView` when a selected log exists. The form has a `Stepper` for count, a notes `TextField`, and save/cancel toolbar actions.

- [ ] **Step 4: Save edits through the ViewModel**

On save, call `updateLog`, dismiss the sheet, and rely on the existing fetch/change-token refresh behavior.

### Task 3: Verification

**Files:**
- Verify all changed Swift files.

- [ ] **Step 1: Run rule checks**

Run `check-rules` for every changed Swift code file.

- [ ] **Step 2: Run tests**

Run targeted tests for the new ViewModel behavior, then run broader available project tests if the local Xcode setup allows it.

- [ ] **Step 3: Run lint/build verification**

Use the repo’s Swift/Xcode verification path. If unavailable in CLI, report the exact blocker and commands attempted.
