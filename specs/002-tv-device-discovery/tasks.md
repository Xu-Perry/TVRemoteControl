# Tasks: TV Device Auto Discovery

**Input**: Design documents from `specs/002-tv-device-discovery/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/discovery-flow.md](contracts/discovery-flow.md), [quickstart.md](quickstart.md)

**Tests**: Required by the project constitution for behavior that can be tested without a real TV.

**Organization**: Tasks are grouped by user story so each story can be implemented and tested independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it touches different files and has no dependency on incomplete tasks.
- **[Story]**: Maps tasks to user stories from [spec.md](spec.md).
- Every task includes an exact repository path.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Align project metadata and docs with automatic discovery before code changes.

- [X] T001 Add local-network permission usage text for TV discovery in `TVRemoteController.xcodeproj/project.pbxproj`
- [X] T002 [P] Update automatic discovery scope and Figma screen references in `docs/AppDesign.md`
- [X] T003 [P] Update native discovery dependency decision in `docs/OpenSourceSDKs.md`
- [X] T004 [P] Add automatic discovery manual smoke outline in `docs/ManualSmokeTest.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add shared model and service boundaries that all discovery stories depend on.

**CRITICAL**: No user story work should begin until this phase is complete.

- [X] T005 [P] Add discovery error cases for no devices, cancellation, and malformed discovery data in `Packages/TVRemoteModules/Sources/TVRemoteCore/DiscoveryError.swift`
- [X] T006 [P] Add TV discovery service protocol and result stream types in `Packages/TVRemoteModules/Sources/TVRemoteNetworking/TVDiscoveryService.swift`
- [X] T007 [P] Add auto-connect dependency slots to app environment construction in `TVRemoteController/AppEnvironment.swift`

**Checkpoint**: Foundation ready - user story implementation can now begin.

---

## Phase 3: User Story 1 - Discover nearby TV TVs (Priority: P1) MVP

**Goal**: A first-time user can start scanning, see scanning progress, and receive a deduplicated list of discovered TV TVs.

**Independent Test**: Start with no saved device, begin scanning through a fake discovery service, and verify first-launch, scanning, cancellation, and devices-found states without real network access.

### Tests for User Story 1

- [X] T008 [P] [US1] Add parser fixture tests for TV device descriptions in `Packages/TVRemoteModules/Tests/TVRemoteNetworkingTests/SSDPDeviceDescriptionParserTests.swift`
- [X] T009 [P] [US1] Add discovery service tests for TV filtering, deduplication, and cancellation in `Packages/TVRemoteModules/Tests/TVRemoteNetworkingTests/TVDiscoveryServiceTests.swift`
- [X] T010 [P] [US1] Add auto-connect scan state tests using a fake discovery service in `TVRemoteControllerTests/AutoConnectViewModelTests.swift`

### Implementation for User Story 1

- [X] T011 [P] [US1] Create discovered TV device model in `Packages/TVRemoteModules/Sources/TVRemoteCore/DiscoveredTVDevice.swift`
- [X] T012 [P] [US1] Create discovery session state model in `Packages/TVRemoteModules/Sources/TVRemoteCore/DiscoverySessionState.swift`
- [X] T013 [US1] Implement SSDP device description parsing in `Packages/TVRemoteModules/Sources/TVRemoteNetworking/SSDPDeviceDescriptionParser.swift`
- [X] T014 [US1] Implement TV discovery aggregation and deduplication in `Packages/TVRemoteModules/Sources/TVRemoteNetworking/TVDiscoveryService.swift`
- [X] T015 [US1] Implement cancellable SSDP network scanning in `Packages/TVRemoteModules/Sources/TVRemoteNetworking/SSDPDiscoveryClient.swift`
- [X] T016 [P] [US1] Create auto-connect UI state types for first-launch, scanning, and devices-found states in `TVRemoteController/Remote/AutoConnectState.swift`
- [X] T017 [US1] Implement scan, cancel, and stale-result protection in `TVRemoteController/Remote/AutoConnectViewModel.swift`
- [X] T018 [US1] Implement first-launch, scanning, and devices-found screens following Figma in `TVRemoteController/Remote/AutoConnectView.swift`
- [X] T019 [US1] Route the no-saved-device experience to auto-connect instead of manual-only setup in `TVRemoteController/Remote/RemotePageView.swift`
- [X] T020 [US1] Wire real and mock discovery dependencies into app construction in `TVRemoteController/AppEnvironment.swift`

**Checkpoint**: User Story 1 independently discovers mock TV devices, supports cancellation, and shows the Figma-aligned discovery list.

---

## Phase 4: User Story 2 - Connect to a discovered TV (Priority: P2)

**Goal**: A user can select a discovered TV TV, see connecting progress, reach connected-ready, and enter the remote.

**Independent Test**: Use a fake discovered device and fake TV client to verify selection, connecting, connected-ready, and remote-entry state transitions.

### Tests for User Story 2

- [X] T021 [P] [US2] Add connection state tests for discovered-device selection and connected-ready success in `TVRemoteControllerTests/AutoConnectConnectionTests.swift`
- [X] T022 [P] [US2] Add package tests for mapping discovered TV devices into connectable TV devices in `Packages/TVRemoteModules/Tests/TVRemoteCoreTests/DiscoveredTVDeviceTests.swift`

### Implementation for User Story 2

- [X] T023 [US2] Add conversion from discovered TV device to saved TV device metadata in `Packages/TVRemoteModules/Sources/TVRemoteCore/DiscoveredTVDevice.swift`
- [X] T024 [US2] Implement select-device and connecting state transitions in `TVRemoteController/Remote/AutoConnectViewModel.swift`
- [X] T025 [US2] Persist successful discovered-device connections through the existing repository boundary in `TVRemoteController/Persistence/DeviceRepository.swift`
- [X] T026 [US2] Add connecting and connected-ready screens following Figma in `TVRemoteController/Remote/AutoConnectView.swift`
- [X] T027 [US2] Integrate enter-remote behavior so the selected TV becomes the remote target in `TVRemoteController/Remote/RemoteViewModels.swift`

**Checkpoint**: User Story 2 independently connects a selected fake discovered TV and enters a connected remote state.

---

## Phase 5: User Story 3 - Recover when no devices are found (Priority: P3)

**Goal**: A user gets useful recovery options when discovery finds no TV, including retry and manual IP entry.

**Independent Test**: Use a fake discovery service returning no devices and verify no-devices state, retry behavior, and manual IP fallback.

### Tests for User Story 3

- [X] T028 [P] [US3] Add no-devices, retry, and manual-entry fallback tests in `TVRemoteControllerTests/AutoConnectRecoveryTests.swift`

### Implementation for User Story 3

- [X] T029 [US3] Implement no-devices and retry state transitions in `TVRemoteController/Remote/AutoConnectViewModel.swift`
- [X] T030 [US3] Implement no-devices recovery UI following Figma in `TVRemoteController/Remote/AutoConnectView.swift`
- [X] T031 [US3] Wire manual IP fallback from auto-connect into the existing settings flow in `TVRemoteController/Remote/RemotePageView.swift`
- [X] T032 [US3] Reuse existing connection error copy for discovery recovery guidance in `TVRemoteController/Remote/RemoteStates.swift`

**Checkpoint**: User Story 3 independently recovers from no discovered devices without app restart.

---

## Phase 6: User Story 4 - Remember and clear the connected TV (Priority: P4)

**Goal**: The app restores a remembered TV TV on later launches and lets users clear that connection after confirmation.

**Independent Test**: Complete a fake successful discovered-device connection, rebuild the view model from persisted state, verify restore, then confirm clear and verify first-launch setup returns.

### Tests for User Story 4

- [X] T033 [P] [US4] Add restore and clear-connection tests in `TVRemoteControllerTests/AutoConnectPersistenceTests.swift`

### Implementation for User Story 4

- [X] T034 [US4] Add delete saved device capability to repository protocol in `TVRemoteController/Persistence/DeviceRepository.swift`
- [X] T035 [US4] Implement metadata and secret deletion for remembered TV clearing in `TVRemoteController/Persistence/DeviceMetadataStore.swift`
- [X] T036 [US4] Implement restore remembered TV and clear confirmation state transitions in `TVRemoteController/Remote/AutoConnectViewModel.swift`
- [X] T037 [US4] Implement clear connection confirmation UI following Figma in `TVRemoteController/Remote/AutoConnectView.swift`
- [X] T038 [US4] Ensure launch restoration updates remote header and remote availability in `TVRemoteController/Remote/RemoteViewModels.swift`

**Checkpoint**: User Story 4 independently restores remembered TVs and clears them only after confirmation.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final documentation, verification, and quality checks across the full discovery chain.

- [X] T039 [P] Update final real-device automatic discovery steps and known limits in `docs/ManualSmokeTest.md`
- [X] T040 [P] Re-run `figma-use status` and reconcile any UI text mismatches against `specs/002-tv-device-discovery/quickstart.md`
- [X] T041 Run app unit tests from `specs/002-tv-device-discovery/quickstart.md`
- [X] T042 Run package tests from `specs/002-tv-device-discovery/quickstart.md`
- [X] T043 Run simulator build from `specs/002-tv-device-discovery/quickstart.md`
- [X] T044 Run `git diff --check` for `/Users/bytedance/Documents/TVRemoteController`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately.
- **Foundational (Phase 2)**: Depends on Setup completion and blocks user stories.
- **User Stories (Phase 3+)**: Depend on Foundational completion.
- **Polish (Phase 7)**: Depends on the desired user stories being complete.

### User Story Dependencies

- **User Story 1 (P1)**: Starts after Foundational and is the MVP.
- **User Story 2 (P2)**: Depends on US1 discovered-device list and shared models.
- **User Story 3 (P3)**: Depends on US1 scan orchestration but can be validated with a fake no-devices result.
- **User Story 4 (P4)**: Depends on US2 successful connection and existing persistence boundaries.

### Within Each User Story

- Tests should be written first and fail before implementation.
- Models before services.
- Services before view models.
- View models before SwiftUI integration.
- Story checkpoint must pass before moving to the next priority story.

### Parallel Opportunities

- T002, T003, and T004 can run in parallel.
- T005, T006, and T007 can run in parallel.
- US1 tests T008, T009, and T010 can run in parallel.
- US1 models T011, T012, and state file T016 can run in parallel after tests are drafted.
- US2 tests T021 and T022 can run in parallel.
- US3 and US4 test files can be drafted in parallel after US1 foundation is stable.
- Polish docs and Figma reconciliation can run in parallel with final verification.

---

## Parallel Example: User Story 1

```text
Task: "Add parser fixture tests for TV device descriptions in Packages/TVRemoteModules/Tests/TVRemoteNetworkingTests/SSDPDeviceDescriptionParserTests.swift"
Task: "Add discovery service tests for TV filtering, deduplication, and cancellation in Packages/TVRemoteModules/Tests/TVRemoteNetworkingTests/TVDiscoveryServiceTests.swift"
Task: "Add auto-connect scan state tests using a fake discovery service in TVRemoteControllerTests/AutoConnectViewModelTests.swift"
```

```text
Task: "Create discovered TV device model in Packages/TVRemoteModules/Sources/TVRemoteCore/DiscoveredTVDevice.swift"
Task: "Create discovery session state model in Packages/TVRemoteModules/Sources/TVRemoteCore/DiscoverySessionState.swift"
Task: "Create auto-connect UI state types for first-launch, scanning, and devices-found states in TVRemoteController/Remote/AutoConnectState.swift"
```

## Parallel Example: User Story 2

```text
Task: "Add connection state tests for discovered-device selection and connected-ready success in TVRemoteControllerTests/AutoConnectConnectionTests.swift"
Task: "Add package tests for mapping discovered TV devices into connectable TV devices in Packages/TVRemoteModules/Tests/TVRemoteCoreTests/DiscoveredTVDeviceTests.swift"
```

## Parallel Example: User Story 3

```text
Task: "Add no-devices, retry, and manual-entry fallback tests in TVRemoteControllerTests/AutoConnectRecoveryTests.swift"
Task: "Implement no-devices recovery UI following Figma in TVRemoteController/Remote/AutoConnectView.swift"
```

## Parallel Example: User Story 4

```text
Task: "Add restore and clear-connection tests in TVRemoteControllerTests/AutoConnectPersistenceTests.swift"
Task: "Implement metadata and secret deletion for remembered TV clearing in TVRemoteController/Persistence/DeviceMetadataStore.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Setup and Foundational phases.
2. Complete User Story 1 tests and implementation.
3. Stop and validate scanning state, cancellation, and devices-found list with fakes.
4. Demo first-launch scanning flow before adding connection.

### Incremental Delivery

1. US1: discover and list TV TVs.
2. US2: connect selected TV and enter remote.
3. US3: recover from no devices and preserve manual IP fallback.
4. US4: restore and clear remembered TV.
5. Polish: docs, Figma check, automated tests, simulator build, manual smoke.

### Parallel Team Strategy

1. One engineer owns package discovery parsing and service tests.
2. One engineer owns app target state/view-model tests.
3. One engineer owns SwiftUI screens once the state contract is stable.
4. Persistence and launch-restore work starts after US2 connection success is defined.

## Notes

- Keep SwiftUI views free of business logic, network calls, persistence, and shared state mutation.
- Keep each new class in its own source file.
- Do not add a third-party dependency unless `docs/OpenSourceSDKs.md` is updated with the decision.
- Do not claim real-device discovery validation until the manual smoke path has been run with a physical TV TV.
