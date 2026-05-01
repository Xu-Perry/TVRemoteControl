# Implementation Plan: BRAVIA Device Auto Discovery

**Branch**: `002-bravia-device-discovery` | **Date**: 2026-05-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/002-bravia-device-discovery/spec.md`

## Summary

Complete the automatic BRAVIA discovery chain shown in the Figma design: first launch, scan, device list, connect, connected-ready, no-devices recovery, and clear remembered connection. The implementation should keep discovery protocol parsing and connection-facing models testable in `Packages/SonyRemoteModules`, while app target code owns SwiftUI state, view models, persistence coordination, and Figma-aligned screens.

## Technical Context

**Language/Version**: Swift 6.0 package tools, iOS app using SwiftUI and Observation  
**Primary Dependencies**: SwiftUI, Observation, Foundation, Network.framework, URLSession, Security; no new third-party packages planned  
**Storage**: Existing `DeviceRepository`, `DeviceMetadataStore`, and `SecretStore` boundaries for remembered TV metadata and PSK storage  
**Testing**: Swift Testing via `import Testing`; package tests under `Packages/SonyRemoteModules/Tests`; app tests under `SonyRemoteControllerTests`  
**Target Platform**: iOS 18+ app, with package code also testable on macOS where practical  
**Project Type**: Native iOS mobile app with local Swift Package modules  
**Performance Goals**: Discovered-device result visible within 15 seconds in normal validation; scan cancellation returns to setup within 1 second; no main-thread blocking during discovery or connection  
**Constraints**: Discovery and connection are local-network behavior; automated tests must use test doubles and fixtures instead of requiring a real BRAVIA TV; real-device smoke is required before claiming end-to-end discovery works  
**Scale/Scope**: One remembered TV target for this feature; manual IP fallback remains; multiple-device switching beyond selecting the discovered TV is out of scope

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Architecture Boundary: PASS. SwiftUI views will render state and forward user intent only. Discovery scanning, connection testing, remembered-device persistence, and cross-component coordination belong in services, repositories, and page view models. New classes should live in separate files.
- Test-Driven Change: PASS. Protocol parsing, deduplication, cancellation-safe state transitions, remembered-device behavior, and no-devices recovery can be covered with automated tests. Real local-network discovery and a physical BRAVIA connection require documented manual smoke coverage.

## Project Structure

### Documentation (this feature)

```text
specs/002-bravia-device-discovery/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── discovery-flow.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
Packages/SonyRemoteModules/
├── Sources/
│   ├── SonyRemoteCore/
│   │   ├── SonyDevice.swift
│   │   ├── DiscoveredBRAVIADevice.swift
│   │   └── DiscoverySessionState.swift
│   └── SonyRemoteNetworking/
│       ├── BRAVIADiscoveryService.swift
│       ├── SSDPDiscoveryClient.swift
│       └── SSDPDeviceDescriptionParser.swift
└── Tests/
    ├── SonyRemoteCoreTests/
    └── SonyRemoteNetworkingTests/

SonyRemoteController/
├── Remote/
│   ├── AutoConnectState.swift
│   ├── AutoConnectView.swift
│   ├── AutoConnectViewModel.swift
│   ├── RemoteStates.swift
│   ├── RemoteViewModels.swift
│   └── RemotePageView.swift
└── Persistence/
    ├── DeviceRepository.swift
    ├── DeviceMetadataStore.swift
    └── SecretStore.swift

SonyRemoteControllerTests/
└── SonyRemoteControllerTests.swift

docs/
├── AppDesign.md
├── ManualSmokeTest.md
└── OpenSourceSDKs.md
```

**Structure Decision**: Reusable discovery models and parsing/network discovery boundaries belong in `Packages/SonyRemoteModules` because they are stable, testable outside SwiftUI, and likely to remain useful beyond one screen. Figma-aligned screen state, navigation, retry/cancel behavior, and remembered-device coordination belong in the app target because they are product-flow specific.

## Phase 0: Research

See [research.md](research.md).

## Phase 1: Design And Contracts

See [data-model.md](data-model.md), [contracts/discovery-flow.md](contracts/discovery-flow.md), and [quickstart.md](quickstart.md).

## Post-Design Constitution Check

- Architecture Boundary: PASS. The design keeps discovery service contracts outside views, gives the page-level view model responsibility for connecting selected devices and updating sibling state, and keeps file ownership aligned with primary types.
- Test-Driven Change: PASS. The quickstart and contracts identify automated tests for parser/service/view-model behavior plus manual smoke validation for real BRAVIA and local-network behavior.

## Complexity Tracking

No constitution violations are planned.
