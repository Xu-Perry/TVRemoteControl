# Tasks: Remote command actions cause visible full-view flicker

**Input**: Design documents from `/specs/001-remote-command-actions-cause-visible-full-view-flicker/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/remote-command-visual-stability.md, quickstart.md

**Tests**: Included because FR-007 and User Story 3 require focused ViewModel/state coverage when command state transitions change.

**Organization**: Tasks are grouped by user story so each story can be implemented and tested independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it touches different files or only reads existing files
- **[Story]**: User story label, required only for user story phases
- Every task includes an exact file path

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm the active feature context and current implementation surface before changing behavior.

- [X] T001 Review current command send state mutations in `TVRemoteController/Remote/RemoteViewModels.swift`
- [X] T002 [P] Review current Remote Page conditional rendering and button disabled logic in `TVRemoteController/Remote/RemotePageView.swift`
- [X] T003 [P] Review existing Remote Page state fields and derived command enablement in `TVRemoteController/Remote/RemoteStates.swift`
- [X] T004 [P] Review existing app test harness and mocks in `TVRemoteControllerTests/TVRemoteControllerTests.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish the shared test seams needed by all user-story work.

**Critical**: No user story implementation should begin until these tasks are complete.

- [X] T005 Add command-send call recording support to `MockTVRemoteClient` in `TVRemoteControllerTests/TVRemoteControllerTests.swift`
- [X] T006 Add a connected remote harness helper that saves a mock device and PSK in `TVRemoteControllerTests/TVRemoteControllerTests.swift`
- [X] T007 Add snapshot helper assertions for stable header/status/remote enabled state in `TVRemoteControllerTests/TVRemoteControllerTests.swift`

**Checkpoint**: Test harness can verify command-send state changes without a real TV TV.

---

## Phase 3: User Story 1 - Send repeated commands without full-page flicker (Priority: P1) MVP

**Goal**: Connected command taps keep the Remote Page header, pad, and controls stable while commands are sent.

**Independent Test**: With a connected mock device, repeated command sends succeed while `RemotePageState.status`, `ConnectionHeaderState`, and `RemotePadState.isEnabled` remain unchanged, and real-device smoke testing shows no full-page flicker.

### Tests for User Story 1

> Write these tests first and confirm they fail if the current implementation does not meet the contract.

- [X] T008 [US1] Add a successful command stability test for `RemotePadViewModel.send(_:)` in `TVRemoteControllerTests/TVRemoteControllerTests.swift`
- [X] T009 [US1] Add a repeated command stability test covering two sequential successful sends in `TVRemoteControllerTests/TVRemoteControllerTests.swift`
- [X] T010 [US1] Add a test that `RemotePadState.isSendingCommand` returns to false after successful send in `TVRemoteControllerTests/TVRemoteControllerTests.swift`

### Implementation for User Story 1

- [X] T011 [US1] Restrict successful command-send mutations to command-local state in `TVRemoteController/Remote/RemoteViewModels.swift`
- [X] T012 [US1] Ensure command progress does not mutate `RemotePageState.status`, `ConnectionHeaderState`, `savedDevice`, or `isSettingsPresented` in `TVRemoteController/Remote/RemoteViewModels.swift`
- [X] T013 [US1] Keep command button feedback local to button style and remote pad state in `TVRemoteController/Remote/RemotePageView.swift`
- [X] T014 [US1] Run the US1 app unit tests from `README.md` using `xcodebuild test -scheme TVRemoteController -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' -only-testing:TVRemoteControllerTests`

**Checkpoint**: User Story 1 is independently functional when connected command success no longer changes broad page state and the focused tests pass.

---

## Phase 4: User Story 2 - Preserve disabled and failure behavior (Priority: P2)

**Goal**: The flicker fix preserves disconnected disabled state and command failure error-banner behavior.

**Independent Test**: With a connected mock device whose command send fails, failure surfaces through `RemotePageState.error` while connected header/control state remains stable; with no usable device, controls remain disabled and no command is dispatched.

### Tests for User Story 2

- [X] T015 [US2] Add a command failure stability test for connected state in `TVRemoteControllerTests/TVRemoteControllerTests.swift`
- [X] T016 [US2] Add a test that failed command sends do not update `RemotePadState.lastCommand` in `TVRemoteControllerTests/TVRemoteControllerTests.swift`
- [X] T017 [US2] Add a disabled-state defensive send test that verifies no command is dispatched in `TVRemoteControllerTests/TVRemoteControllerTests.swift`
- [X] T018 [US2] Add a test that `RemotePadState.isSendingCommand` returns to false after command failure in `TVRemoteControllerTests/TVRemoteControllerTests.swift`

### Implementation for User Story 2

- [X] T019 [US2] Preserve best-known connected `ConnectionStatus` for transient command failures in `TVRemoteController/Remote/RemoteViewModels.swift`
- [X] T020 [US2] Keep existing layered error mapping for command failures in `TVRemoteController/Remote/RemoteViewModels.swift`
- [X] T021 [US2] Verify disabled button conditions remain tied to `RemotePadState.isEnabled` without using `isSendingCommand` to restyle the full control set in `TVRemoteController/Remote/RemotePageView.swift`
- [X] T022 [US2] Run the US2 app unit tests from `README.md` using `xcodebuild test -scheme TVRemoteController -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' -only-testing:TVRemoteControllerTests`

**Checkpoint**: User Story 2 is independently functional when failure and disabled-state tests pass without regressing US1.

---

## Phase 5: User Story 3 - Maintain focused regression coverage (Priority: P3)

**Goal**: Regression coverage clearly documents the command state transition contract and protects against broad page-level state churn.

**Independent Test**: The relevant ViewModel/state tests pass and fail meaningfully if command sends mutate unrelated page state.

### Tests for User Story 3

- [X] T023 [US3] Refactor command stability tests into clearly named test methods in `TVRemoteControllerTests/TVRemoteControllerTests.swift`
- [X] T024 [US3] Add comments or assertion grouping that names the stable-state contract in `TVRemoteControllerTests/TVRemoteControllerTests.swift`

### Implementation for User Story 3

- [X] T025 [US3] Update manual smoke coverage for repeated command flicker checks in `docs/ManualSmokeTest.md`
- [X] T026 [US3] Run all app unit tests from `README.md` using `xcodebuild test -scheme TVRemoteController -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' -only-testing:TVRemoteControllerTests`

**Checkpoint**: User Story 3 is complete when regression tests and manual smoke instructions both cover the visual stability contract.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup across the feature.

- [X] T027 [P] Run the app build command from `README.md` using `xcodebuild build -scheme TVRemoteController -destination 'generic/platform=iOS Simulator' -quiet`
- [X] T028 [P] Run package tests from `README.md` using `cd Packages/TVRemoteModules && env CLANG_MODULE_CACHE_PATH=/private/tmp/tvremote-clang-cache swift test`
- [X] T029 Review final Remote Page changes for constitution architecture boundaries in `TVRemoteController/Remote/RemoteViewModels.swift`
- [X] T030 Review final Remote Page rendering changes against design guidance in `docs/AppDesign.md`
- [ ] T031 Record real-device smoke result for repeated command taps in `docs/ManualSmokeTest.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup; blocks all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational; recommended MVP.
- **User Story 2 (Phase 4)**: Depends on Foundational; can be implemented after or alongside US1, but should be validated after US1 to catch regressions.
- **User Story 3 (Phase 5)**: Depends on US1 and US2 test shape, because it consolidates regression coverage and manual smoke documentation.
- **Polish (Phase 6)**: Depends on all desired user stories being complete.

### User Story Dependencies

- **US1 (P1)**: No dependency on other user stories after Foundational.
- **US2 (P2)**: No implementation dependency on US1, but should preserve US1 stability tests.
- **US3 (P3)**: Depends on the final US1/US2 state transition tests.

### Within Each User Story

- Write tests before implementation tasks.
- Keep ViewModel/state changes before view refinements.
- Run the story-specific test task before marking the story complete.

---

## Parallel Opportunities

- T002, T003, and T004 can run in parallel during Setup.
- US1 test tasks T008, T009, and T010 are intentionally sequential because they edit the same test file.
- US2 test tasks T015, T016, T017, and T018 are intentionally sequential because they edit the same test file.
- T027 and T028 can run in parallel during Polish because app build and package tests use different build roots.

## Parallel Example: User Story 1

```text
Task: "T008 [US1] Add a successful command stability test for RemotePadViewModel.send(_:) in TVRemoteControllerTests/TVRemoteControllerTests.swift"
Task: "T009 [US1] Add a repeated command stability test covering two sequential successful sends in TVRemoteControllerTests/TVRemoteControllerTests.swift"
Task: "T010 [US1] Add a test that RemotePadState.isSendingCommand returns to false after successful send in TVRemoteControllerTests/TVRemoteControllerTests.swift"
```

## Parallel Example: User Story 2

```text
Task: "T015 [US2] Add a command failure stability test for connected state in TVRemoteControllerTests/TVRemoteControllerTests.swift"
Task: "T016 [US2] Add a test that failed command sends do not update RemotePadState.lastCommand in TVRemoteControllerTests/TVRemoteControllerTests.swift"
Task: "T017 [US2] Add a disabled-state defensive send test that verifies no command is dispatched in TVRemoteControllerTests/TVRemoteControllerTests.swift"
Task: "T018 [US2] Add a test that RemotePadState.isSendingCommand returns to false after command failure in TVRemoteControllerTests/TVRemoteControllerTests.swift"
```

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 and Phase 2.
2. Complete US1 tests T008-T010.
3. Implement US1 changes T011-T013.
4. Run T014 and perform the real-device repeated-tap smoke check for the success path.

### Incremental Delivery

1. Deliver US1 to stop full-page flicker on successful command sends.
2. Deliver US2 to ensure failure and disabled states still behave correctly.
3. Deliver US3 to harden regression coverage and manual smoke documentation.
4. Complete Polish validation across app build, app tests, and package tests.

### Notes

- Keep the implementation in the app target unless a stable reusable package boundary becomes clear.
- Do not add third-party dependencies for this feature.
- Avoid broad refactors of the Remote Page while implementing the focused flicker fix.
