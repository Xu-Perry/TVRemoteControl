# Implementation Plan: Figma App Page Restoration

**Branch**: `003-restore-app-pages` | **Date**: 2026-05-06 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/003-restore-app-pages/spec.md`

## Summary

Restore the daily-use remote experience from the latest Figma file `BRAVIA Controller UI Kit`: main remote, input source bottom sheet, keyboard input full-screen page, more keys bottom sheet, and settings page. Keep the work in the app target because it is product-flow UI and page state, reuse existing BRAVIA command and persistence services, and add focused Swift Testing coverage around navigation state, inactive about rows, settings preferences, keyboard draft behavior, and command dispatch boundaries.

## Technical Context

**Language/Version**: Swift 6.0 package tools, iOS app using SwiftUI and Observation  
**Primary Dependencies**: SwiftUI, Observation, Foundation, SonyRemoteCore, SonyRemoteNetworking; no new third-party packages planned  
**Storage**: Existing `DeviceRepository`, `DeviceMetadataStore`, and `SecretStore` for saved TV metadata and credentials; lightweight app preference persistence may stay in app target if implemented  
**Testing**: Swift Testing via `import Testing`; app tests under `SonyRemoteControllerTests`; package tests under `Packages/SonyRemoteModules/Tests` only if shared command mappings change  
**Target Platform**: iOS 18+ portrait iPhone app  
**Project Type**: Native iOS mobile app  
**Performance Goals**: Main and secondary remote pages respond to taps immediately; sheet or full-screen presentations appear without visible layout jump; command progress must not repaint unrelated page regions  
**Constraints**: UI must follow the latest Figma frames and design tokens; no bottom tab bar; no new package extraction unless stable reusable domain logic appears; tests must not require a real BRAVIA TV or local network  
**Scale/Scope**: Five Figma-backed app states for this feature: main remote, input source sheet, keyboard input, more keys sheet, and settings; existing auto-connect flow remains the no-device entry path

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Architecture Boundary: PASS. The plan keeps SwiftUI views responsible for rendering and forwarding user intent only. Page-level coordination belongs in `RemotePageViewModel`; remote subflows get explicit state fields and intent methods. New classes, if needed, must live in separate files.
- Test-Driven Change: PASS. Navigation state, about-row no-op behavior, keyboard draft mutation, source/more-key command mapping, and preference toggles can be covered with app tests and test doubles. Figma visual parity remains a manual/screenshot validation item because it depends on rendered UI.

## Project Structure

### Documentation (this feature)

```text
specs/003-restore-app-pages/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── ui-restoration.md
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
SonyRemoteController/
├── Remote/
│   ├── RemoteStates.swift
│   ├── RemoteViewModels.swift
│   ├── RemotePageView.swift
│   └── DeviceSettingsView.swift
├── Persistence/
│   ├── DeviceRepository.swift
│   ├── DeviceMetadataStore.swift
│   └── SecretStore.swift
└── AppEnvironment.swift

SonyRemoteControllerTests/
├── SonyRemoteControllerTests.swift
└── RemotePageRestorationTests.swift

Packages/SonyRemoteModules/
├── Sources/SonyRemoteCore/RemoteCommand.swift
└── Tests/SonyRemoteCoreTests/RemoteCommandTests.swift
```

**Structure Decision**: Keep this feature in the app target. The work is primarily page composition, presentation state, settings rows, keyboard draft state, and Figma-aligned visual structure. Existing package code already owns reusable BRAVIA commands and networking; only touch `Packages/SonyRemoteModules` if a missing command mapping is required by the restored pages.

## Phase 0: Research

See [research.md](research.md).

## Phase 1: Design And Contracts

See [data-model.md](data-model.md), [contracts/ui-restoration.md](contracts/ui-restoration.md), and [quickstart.md](quickstart.md).

## Post-Design Constitution Check

- Architecture Boundary: PASS. The data model keeps page state explicit and keeps secondary page presentation, keyboard draft, source selection, settings preferences, and about-row behavior out of view bodies. The contract requires page view model ownership for cross-page transitions.
- Test-Driven Change: PASS. The quickstart defines app-level automated tests for state transitions and no-op about rows, plus screenshot/manual checks for Figma parity. No real TV is required for the planned automated coverage.

## Complexity Tracking

No constitution violations are planned.
