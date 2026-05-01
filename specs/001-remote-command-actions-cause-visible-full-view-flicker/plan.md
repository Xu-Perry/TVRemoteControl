# Implementation Plan: Remote command actions cause visible full-view flicker

**Branch**: `001-remote-command-actions-cause-visible-full-view-flicker` | **Date**: 2026-04-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-remote-command-actions-cause-visible-full-view-flicker/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Fix visible full-page flicker when sending remote commands from the Remote Page while preserving connected/disconnected behavior and command failure messaging. The implementation should stay in the app target's `SonyRemoteController/Remote` feature files, decouple transient command-send feedback from broad page-level state/identity changes, and add focused Swift Testing coverage for remote command state transitions. Real-device smoke testing remains required because the reported flicker is visual and hardware-confirmed.

## Technical Context

**Language/Version**: Swift for iOS 18 app development, using SwiftUI and Observation
**Primary Dependencies**: SwiftUI, Observation, SonyRemoteCore, SonyRemoteNetworking; no new third-party dependencies
**Storage**: Existing local device repository, UserDefaults metadata, and Keychain-backed PSK storage; no storage schema changes expected
**Testing**: Swift Testing (`import Testing`) in `SonyRemoteControllerTests`; package tests remain available for shared core/networking behavior
**Target Platform**: iPhone portrait app, iOS 18+ per README/project direction
**Project Type**: Mobile app with local Swift Package modules
**Performance Goals**: Remote command taps should keep the Remote Page visually stable at normal interactive frame rates, with no visible full-page flash during repeated taps
**Constraints**: UI state mutation stays on the main actor; network command dispatch remains asynchronous; tests must not require a real BRAVIA TV; real-device visual validation is manual smoke coverage
**Scale/Scope**: One app screen/feature area: Remote Page command interactions, error banner behavior, and view-model state transitions

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Architecture Boundary: Does the plan keep SwiftUI views free of business
  logic, side effects, and shared state mutation, with page view models owning
  cross-component coordination, and each class in its own source file?
  - PASS: The fix is planned in `RemotePageViewModel`, `RemotePadViewModel`, and state/view composition as needed. Views continue forwarding user intent only and do not gain command dispatch logic beyond existing intent calls. If class extraction is needed, each class will live in its own source file to comply with constitution version 2.1.0.
- Test-Driven Change: Does the plan define focused automated tests for behavior
  that can be tested without a real TV, plus manual smoke coverage where real
  device or local-network behavior is required?
  - PASS: Automated Swift Testing coverage will target ViewModel/state transitions using existing test doubles. Manual real-device smoke steps will cover the visual no-flicker requirement that cannot be fully proven by unit tests.

## Project Structure

### Documentation (this feature)

```text
specs/001-remote-command-actions-cause-visible-full-view-flicker/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
SonyRemoteController/
├── Remote/
│   ├── RemotePageView.swift       # Remote Page UI composition and button views
│   ├── RemoteStates.swift         # Observable page/header/settings/remote pad state
│   └── RemoteViewModels.swift     # Page, settings, and remote pad orchestration
└── Persistence/
    ├── DeviceRepository.swift
    ├── DeviceMetadataStore.swift
    └── SecretStore.swift

SonyRemoteControllerTests/
└── SonyRemoteControllerTests.swift # Existing Swift Testing target and test doubles

Packages/SonyRemoteModules/
├── Sources/
│   ├── SonyRemoteCore/
│   └── SonyRemoteNetworking/
└── Tests/
    ├── SonyRemoteCoreTests/
    └── SonyRemoteNetworkingTests/
```

**Structure Decision**: Keep this feature in the app target under `SonyRemoteController/Remote`. The behavior is Remote Page UI/state orchestration, not a reusable Sony protocol or networking primitive, so no SPM module extraction is planned. Existing `SonyRemoteCore` and `SonyRemoteNetworking` contracts remain unchanged.

## Phase 0: Research Summary

See [research.md](research.md). Decisions:

- Keep command progress local to remote pad command state, not page-level connection state.
- Preserve connected status on transient command failures and only update the layered error banner.
- Avoid conditional identity changes and broad implicit animation around command progress.
- Add ViewModel/state tests with test doubles and keep visual no-flicker verification in manual smoke.

## Phase 1: Design Summary

See [data-model.md](data-model.md), [contracts/remote-command-visual-stability.md](contracts/remote-command-visual-stability.md), and [quickstart.md](quickstart.md).

The implementation should preserve the current `RemotePageState` tree, refine state mutation boundaries around `RemotePadState.isSendingCommand`, `RemotePadState.lastCommand`, `RemotePageState.status`, and `RemotePageState.error`, and verify that command sends do not mutate unrelated header/status state on success or transient failure.

## Post-Design Constitution Check

- Architecture Boundary: PASS. The design keeps business decisions and side effects in ViewModels/services, keeps SwiftUI views as state readers/intent forwarders, and does not introduce sibling child-view-model coordination.
- Test-Driven Change: PASS. The design specifies automated ViewModel/state transition tests for command success/failure and manual smoke coverage for real-device flicker.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |
