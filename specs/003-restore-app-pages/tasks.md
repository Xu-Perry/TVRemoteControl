# Tasks: Figma App Page Restoration

**Input**: Design documents from `specs/003-restore-app-pages/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ui-restoration.md, quickstart.md

**Tests**: Included because the plan requires focused Swift Testing coverage for behavior that can be tested without a real TV.

**Organization**: Tasks are grouped by user story so each story can be implemented and tested independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it touches different files and has no dependency on another incomplete task
- **[Story]**: Maps the task to a user story from `spec.md`
- Every task includes an exact file path

## Phase 1: Setup

**Purpose**: Confirm the feature context and create the test entry point.

- [x] T001 Verify the latest Figma frames listed in `specs/003-restore-app-pages/contracts/ui-restoration.md` are still present with `figma-use query "//FRAME"`
- [x] T002 [P] Create an empty `RemotePageRestorationTests` Swift Testing suite in `TVRemoteControllerTests/RemotePageRestorationTests.swift`
- [x] T003 Add `TVRemoteControllerTests/RemotePageRestorationTests.swift` to the `TVRemoteControllerTests` target in `TVRemoteController.xcodeproj/project.pbxproj` (target uses Xcode file-system synchronization, so no `project.pbxproj` edit was required)

---

## Phase 2: Foundational

**Purpose**: Add shared state and intent seams that all restored pages depend on.

**Critical**: No user story implementation should begin until this phase is complete.

- [x] T004 [P] Add `RemoteSurface`, `InputSourceOption`, `KeyboardDraft`, `MoreKeyAction`, and `RemotePreferences` state types in `TVRemoteController/Remote/RemoteStates.swift`
- [x] T005 Add `presentedRemoteSurface`, `isKeyboardInputActive`, `inputSources`, `keyboardDraft`, and `remotePreferences` fields to `RemotePageState` in `TVRemoteController/Remote/RemoteStates.swift`
- [x] T006 Add open/dismiss intent methods for input source, keyboard input, more keys, and settings surfaces in `TVRemoteController/Remote/RemoteViewModels.swift`
- [x] T007 Add default input source and more-key model factories in `TVRemoteController/Remote/RemoteViewModels.swift`
- [x] T008 [P] Add package tests for any newly supported TV remote commands in `Packages/TVRemoteModules/Tests/TVRemoteCoreTests/RemoteCommandTests.swift`
- [x] T009 Implement any newly supported TV remote command mappings in `Packages/TVRemoteModules/Sources/TVRemoteCore/RemoteCommand.swift`

**Checkpoint**: Shared state and command capability boundaries are ready for story work.

---

## Phase 3: User Story 1 - Use the restored main remote page (Priority: P1)

**Goal**: Connected users see a Figma-aligned daily-use main remote page.

**Independent Test**: Open the app with a connected TV state and compare the main page against Figma frame `01 Main Remote`.

### Tests for User Story 1

- [x] T010 [P] [US1] Add a connected-state test that disables auto-connect and exposes the main remote page state in `TVRemoteControllerTests/RemotePageRestorationTests.swift`
- [x] T011 [P] [US1] Add a test that command sends do not change `presentedRemoteSurface`, connected device, or settings presentation state in `TVRemoteControllerTests/RemotePageRestorationTests.swift`
- [x] T012 [P] [US1] Add a test that no-device state keeps the existing auto-connect entry path in `TVRemoteControllerTests/RemotePageRestorationTests.swift`

### Implementation for User Story 1

- [x] T013 [US1] Replace the current simplified remote layout with the Figma `01 Main Remote` structure in `TVRemoteController/Remote/RemotePageView.swift`
- [x] T014 [US1] Implement the connected device card with thumbnail, device name, status dot, connected text, and settings affordance in `TVRemoteController/Remote/RemotePageView.swift`
- [x] T015 [US1] Implement vertical `音量` and `频道` control groups with stable dimensions and disabled styling in `TVRemoteController/Remote/RemotePageView.swift`
- [x] T016 [US1] Implement the circular directional pad and centered `OK` control using existing remote command dispatch in `TVRemoteController/Remote/RemotePageView.swift`
- [x] T017 [US1] Implement power, home, back, and mute controls with Figma-aligned labels and SF Symbols in `TVRemoteController/Remote/RemotePageView.swift`
- [x] T018 [US1] Add the `输入源`, `键盘输入`, and `更多按键` lower action cards wired to view model open intents in `TVRemoteController/Remote/RemotePageView.swift`
- [x] T019 [US1] Preserve the existing auto-connect presentation when `isAutoConnectPresented` is true in `TVRemoteController/Remote/RemotePageView.swift`

**Checkpoint**: User Story 1 is functional and independently testable.

---

## Phase 4: User Story 2 - Access secondary remote controls from the main page (Priority: P2)

**Goal**: Users can open and use input source, keyboard input, and more keys surfaces from the main remote page.

**Independent Test**: Launch each secondary control from the main page and compare against Figma frames `03 Input Source Sheet`, `04 Keyboard Input`, and `05 More Keys Sheet`.

### Tests for User Story 2

- [x] T020 [P] [US2] Add tests for opening and dismissing input source, keyboard input, and more keys while preserving connected device state in `TVRemoteControllerTests/RemotePageRestorationTests.swift`
- [x] T021 [P] [US2] Add tests for keyboard draft clear, delete, character count, and connected-target text in `TVRemoteControllerTests/RemotePageRestorationTests.swift`
- [x] T022 [P] [US2] Add tests that unsupported more-key actions are disabled or non-dispatching in `TVRemoteControllerTests/RemotePageRestorationTests.swift`

### Implementation for User Story 2

- [x] T023 [US2] Implement the input source bottom sheet presentation and dismissal binding in `TVRemoteController/Remote/RemotePageView.swift`
- [x] T024 [US2] Implement input source rows for `电视直播`, `HDMI 1`, `HDMI 2`, `HDMI 3`, and `USB` with selected-state rendering in `TVRemoteController/Remote/RemotePageView.swift`
- [x] T025 [US2] Implement the keyboard input bar above the system keyboard without page navigation in `TVRemoteController/Remote/RemotePageView.swift`
- [x] T026 [US2] Implement keyboard input target context, text entry, character count, send, clear, and delete controls in `TVRemoteController/Remote/RemotePageView.swift`
- [x] T027 [US2] Add keyboard draft clear, delete, and send intent methods in `TVRemoteController/Remote/RemoteViewModels.swift`
- [x] T028 [US2] Implement the more keys bottom sheet presentation and dismissal binding in `TVRemoteController/Remote/RemotePageView.swift`
- [x] T029 [US2] Implement numeric keys, menu, back, info, and options rendering in `TVRemoteController/Remote/RemotePageView.swift`

**Checkpoint**: User Stories 1 and 2 are functional and independently testable.

---

## Phase 5: User Story 3 - Manage settings with design-aligned sections (Priority: P3)

**Goal**: Users see the Figma settings page with device, remote, and about sections, while about rows remain non-navigating.

**Independent Test**: Open settings from the main page and compare against Figma frame `06 Settings`; tapping `关于` rows must not navigate.

### Tests for User Story 3

- [x] T030 [P] [US3] Add tests that settings open and close from the main page without changing connected device context in `TVRemoteControllerTests/RemotePageRestorationTests.swift`
- [x] T031 [P] [US3] Add tests that remote preference toggles mutate `RemotePreferences` through the view model in `TVRemoteControllerTests/RemotePageRestorationTests.swift`
- [x] T032 [P] [US3] Add tests that `帮助与反馈`, `隐私政策`, and `关于应用` actions do not change navigation state in `TVRemoteControllerTests/RemotePageRestorationTests.swift`

### Implementation for User Story 3

- [x] T033 [US3] Replace the current form-style settings page with the Figma `06 Settings` grouped settings layout in `TVRemoteController/Remote/DeviceSettingsView.swift`
- [x] T034 [US3] Implement the settings connected device card, back action, and title `设置` in `TVRemoteController/Remote/DeviceSettingsView.swift`
- [x] T035 [US3] Implement the `设备` section rows `设备管理`, `自动连接`, and `忘记此设备` in `TVRemoteController/Remote/DeviceSettingsView.swift`
- [x] T036 [US3] Implement the `遥控器` section rows `按键震动反馈`, `长按连续发送`, and `保持屏幕常亮` with view model-backed toggles in `TVRemoteController/Remote/DeviceSettingsView.swift`
- [x] T037 [US3] Add remote preference toggle intent methods in `TVRemoteController/Remote/RemoteViewModels.swift`
- [x] T038 [US3] Implement the `关于` section rows `帮助与反馈`, `隐私政策`, and `关于应用` as visible no-op rows in `TVRemoteController/Remote/DeviceSettingsView.swift`

**Checkpoint**: All user stories are functional and independently testable.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Validate Figma parity, accessibility, and regression safety across the full feature.

- [x] T039 [P] Add or update SwiftUI previews for connected main remote, input source sheet, keyboard input, more keys sheet, and settings in `TVRemoteController/Remote/RemotePageView.swift`
- [x] T040 [P] Add or update SwiftUI previews for the restored settings states in `TVRemoteController/Remote/DeviceSettingsView.swift`
- [x] T041 Run `xcodebuild test -scheme TVRemoteController -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' -only-testing:TVRemoteControllerTests` from `/Users/bytedance/Documents/TVRemoteController`
- [x] T042 Run `cd Packages/TVRemoteModules && env CLANG_MODULE_CACHE_PATH=/private/tmp/tvremote-clang-cache swift test` from `/Users/bytedance/Documents/TVRemoteController`
- [x] T043 Run `xcodebuild build -scheme TVRemoteController -destination 'generic/platform=iOS Simulator' -quiet` from `/Users/bytedance/Documents/TVRemoteController`
- [ ] T044 Manually compare simulator UI against Figma frames using `specs/003-restore-app-pages/quickstart.md`
- [x] T045 Run `git diff --check` from `/Users/bytedance/Documents/TVRemoteController`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup completion and blocks all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational. This is the MVP.
- **User Story 2 (Phase 4)**: Depends on Foundational and can be developed after the lower action cards from US1 exist.
- **User Story 3 (Phase 5)**: Depends on Foundational and can be developed independently of US2.
- **Polish (Phase 6)**: Depends on completed target user stories.

### User Story Dependencies

- **US1**: No dependency on US2 or US3; delivers the restored main remote MVP.
- **US2**: Depends on the shared presentation state and benefits from US1 lower action cards, but its state behavior is independently testable.
- **US3**: Depends on shared remote preference state and settings navigation, but does not depend on US2.

### Within Each User Story

- Write tests first and confirm they fail before implementing the story.
- Implement state and view model behavior before UI wiring.
- Implement UI structure before visual polish.
- Validate the story independently before moving to the next priority.

## Parallel Opportunities

- T002 can run while T001 verifies Figma.
- T004 and T008 can run in parallel because they touch app state and package tests separately.
- T010, T011, and T012 can be written in parallel within US1.
- T020, T021, and T022 can be written in parallel within US2.
- T030, T031, and T032 can be written in parallel within US3.
- US2 and US3 can proceed in parallel after Phase 2 if different implementers own `RemotePageView.swift` and `DeviceSettingsView.swift`.
- T039 and T040 can run in parallel during polish.

## Parallel Example: User Story 1

```text
Task: "T010 [P] [US1] Add a connected-state test that disables auto-connect and exposes the main remote page state in TVRemoteControllerTests/RemotePageRestorationTests.swift"
Task: "T011 [P] [US1] Add a test that command sends do not change presentedRemoteSurface, connected device, or settings presentation state in TVRemoteControllerTests/RemotePageRestorationTests.swift"
Task: "T012 [P] [US1] Add a test that no-device state keeps the existing auto-connect entry path in TVRemoteControllerTests/RemotePageRestorationTests.swift"
```

## Parallel Example: User Story 2

```text
Task: "T020 [P] [US2] Add tests for opening and dismissing input source, keyboard input, and more keys while preserving connected device state in TVRemoteControllerTests/RemotePageRestorationTests.swift"
Task: "T021 [P] [US2] Add tests for keyboard draft clear, delete, character count, and connected-target text in TVRemoteControllerTests/RemotePageRestorationTests.swift"
Task: "T022 [P] [US2] Add tests that unsupported more-key actions are disabled or non-dispatching in TVRemoteControllerTests/RemotePageRestorationTests.swift"
```

## Parallel Example: User Story 3

```text
Task: "T030 [P] [US3] Add tests that settings open and close from the main page without changing connected device context in TVRemoteControllerTests/RemotePageRestorationTests.swift"
Task: "T031 [P] [US3] Add tests that remote preference toggles mutate RemotePreferences through the view model in TVRemoteControllerTests/RemotePageRestorationTests.swift"
Task: "T032 [P] [US3] Add tests that 帮助与反馈, 隐私政策, and 关于应用 actions do not change navigation state in TVRemoteControllerTests/RemotePageRestorationTests.swift"
```

## Implementation Strategy

### MVP First: User Story 1

1. Complete Phase 1 and Phase 2.
2. Complete US1 tests T010-T012 and confirm they fail before implementation.
3. Complete US1 implementation T013-T019.
4. Run the app test target and manually compare `01 Main Remote`.

### Incremental Delivery

1. Deliver US1 as the restored main remote MVP.
2. Add US2 secondary surfaces without changing the US1 connected remote contract.
3. Add US3 settings restoration with inactive about rows.
4. Complete polish and validation tasks.

### Team Parallelism

After Phase 2:
- One implementer can own `TVRemoteController/Remote/RemotePageView.swift` for US1 and US2.
- One implementer can own `TVRemoteController/Remote/DeviceSettingsView.swift` for US3.
- One implementer can own tests in `TVRemoteControllerTests/RemotePageRestorationTests.swift`, coordinating expected state names with implementation.

## Notes

- The current plan keeps implementation in the app target unless missing TV command mappings require package updates.
- `关于` rows must remain visible but non-navigating.
- Unsupported more-key commands must be disabled or explicitly modeled as unavailable; do not make silent tappable controls.
- Preserve the existing auto-connect flow for no-device state.
