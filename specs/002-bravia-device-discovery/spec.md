# Feature Specification: BRAVIA Device Auto Discovery

**Feature Branch**: `[002-bravia-device-discovery]`
**Created**: 2026-05-01
**Status**: Draft
**Input**: User description: "产品设计稿已经出了，可以使用figma-use cli来查看，然后本次需求需要完成下自动发现brivia设备链路，把自动发现流程跑通"

## Overview

Users need the app to automatically discover Sony BRAVIA TVs on the same local network, choose a discovered device, connect to it, remember the successful connection, and return directly to the remote-control experience on later launches. The product design in Figma defines the expected flow: first launch, scanning, devices found, connecting, connected, no devices, and clear connection confirmation.

This feature updates the previous v1 scope by making automatic BRAVIA discovery part of the setup and connection experience.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Discover nearby BRAVIA TVs (Priority: P1)

As a first-time user, I want the app to scan my local network for BRAVIA TVs so that I can set up the remote without manually entering network details.

**Why this priority**: Discovery is the entry point for the requested end-to-end flow. Without it, users cannot reach the device selection or connection states shown in the product design.

**Independent Test**: Start from an app state with no saved device, begin scanning, and verify that the user sees scanning progress followed by a list of discovered BRAVIA TVs when devices are available.

**Acceptance Scenarios**:

1. **Given** no saved TV exists, **When** the user opens the app, **Then** the app presents a BRAVIA connection entry screen with actions to scan nearby devices and manually enter an IP address.
2. **Given** the user starts scanning, **When** discovery is in progress, **Then** the app shows a scanning state with a clear cancel action.
3. **Given** one or more BRAVIA TVs are found, **When** scanning completes, **Then** the app lists each discovered TV with a recognizable device name and connection status.

---

### User Story 2 - Connect to a discovered TV (Priority: P2)

As a user, I want to select a discovered BRAVIA TV and connect to it so that the app becomes ready to control that TV.

**Why this priority**: Discovery only creates value when it leads into a successful connection and the remote-control experience.

**Independent Test**: Use a discovered TV from the device list, select it, and verify that the app shows a connecting state followed by a ready state with an action to enter the remote.

**Acceptance Scenarios**:

1. **Given** discovered devices are visible, **When** the user selects a connectable TV, **Then** the app shows a connecting state for the selected TV.
2. **Given** the selected TV connection succeeds, **When** the app reaches the connected state, **Then** it confirms the TV is ready and offers entry into the remote.
3. **Given** the user enters the remote after a successful connection, **When** the remote page appears, **Then** it shows the selected BRAVIA TV as connected.

---

### User Story 3 - Recover when no devices are found (Priority: P3)

As a user whose TV is not discovered, I want clear recovery options so that I can retry discovery or connect manually.

**Why this priority**: Local-network discovery can fail for normal household reasons such as Wi-Fi mismatch, TV power state, or TV permissions. The flow must keep users moving instead of ending at an empty state.

**Independent Test**: Run discovery in an environment with no discoverable BRAVIA TVs and verify that the app presents a no-devices state with retry, manual IP entry, and troubleshooting guidance.

**Acceptance Scenarios**:

1. **Given** no BRAVIA TV is discovered, **When** discovery finishes, **Then** the app shows a no-devices state that explains no TV was found on the same network.
2. **Given** the no-devices state is visible, **When** the user chooses retry, **Then** the app starts a new scan.
3. **Given** the no-devices state is visible, **When** the user chooses manual IP entry, **Then** the app lets the user continue setup through the existing manual connection path.

---

### User Story 4 - Remember and clear the connected TV (Priority: P4)

As a returning user, I want the app to remember my connected BRAVIA TV and let me clear that connection when needed so that daily use is fast and device changes remain possible.

**Why this priority**: The design states that connected devices are remembered for future launches. Clearing the connection is necessary when the user changes TVs or wants to reset setup.

**Independent Test**: Complete a successful discovery connection, relaunch the app, and verify that the saved TV is restored; then clear the connection and verify that the app returns to first-launch setup.

**Acceptance Scenarios**:

1. **Given** the user successfully connected to a discovered TV, **When** the app launches later, **Then** it automatically restores that TV as the default target when possible.
2. **Given** a remembered TV exists, **When** the user chooses to clear the connection and confirms, **Then** the app removes the remembered TV and returns to the setup flow.

### Edge Cases

- The user cancels scanning before any devices are found.
- Discovery returns duplicate entries for the same TV.
- A previously paired TV and an unpaired TV both appear in the discovered-device list.
- The selected TV becomes unavailable while connecting.
- Local-network permissions, Wi-Fi mismatch, TV power state, or TV network-control settings prevent discovery.
- A scan finds devices after the user has already cancelled or navigated away.
- The user retries scanning multiple times in a row.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide an automatic BRAVIA discovery entry point when no usable TV connection is saved.
- **FR-002**: The system MUST allow users to start scanning for BRAVIA TVs on the same local network.
- **FR-003**: The system MUST show an in-progress scanning state while discovery is running.
- **FR-004**: Users MUST be able to cancel an active scan and return to the prior setup state.
- **FR-005**: The system MUST list discovered BRAVIA TVs with enough information for users to distinguish devices, including device name when available.
- **FR-006**: The system MUST identify whether a discovered TV is already paired or otherwise ready for connection when that status is known.
- **FR-007**: Users MUST be able to retry scanning from both the devices-found state and the no-devices state.
- **FR-008**: Users MUST be able to select a discovered TV and start connecting to it.
- **FR-009**: The system MUST show a connecting state tied to the selected TV while the connection attempt is in progress.
- **FR-010**: The system MUST show a connected-ready state after a successful connection to a discovered TV.
- **FR-011**: Users MUST be able to enter the remote-control experience from the connected-ready state.
- **FR-012**: The system MUST remember the successfully connected TV for future app launches.
- **FR-013**: The system MUST attempt to restore the remembered TV as the current target on later app launches.
- **FR-014**: Users MUST be able to clear a remembered TV connection only after confirming the destructive action.
- **FR-015**: The system MUST preserve a manual IP entry path for cases where automatic discovery does not find the TV.
- **FR-016**: The system MUST provide user-facing troubleshooting guidance when no devices are found.
- **FR-017**: The system MUST avoid showing stale scan results after the user cancels scanning or starts a newer scan.

### Key Entities

- **Discovered BRAVIA TV**: A TV found on the local network. Key attributes include display name, network address, unique identity when available, and connection readiness status.
- **Discovery Session**: A user-started scan for nearby BRAVIA TVs. Key attributes include progress state, discovered devices, cancellation state, and completion outcome.
- **Remembered TV Connection**: The TV selected by the user after a successful connection. Key attributes include display name, network address, connection status, and saved setup data needed for future launches.
- **Connection Attempt**: A user-initiated attempt to connect to one selected TV. Key attributes include selected TV, progress state, success outcome, and failure reason.

## Design Reference

Figma file `BRAVIA Controller UI Kit` defines the following relevant screens:

- `02A Auto Connect - First Launch`
- `02B Auto Connect - Scanning`
- `02C Auto Connect - Devices Found`
- `02D Auto Connect - Connecting`
- `02E Auto Connect - Connected`
- `02F Auto Connect - No Devices`
- `02G Auto Connect - Clear Confirmation`

The Figma text also states: "连接后会自动记住设备，下次打开 App 可直接进入遥控器。"

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A first-time user can complete the happy path from scan start to remote entry in under 2 minutes when a compatible BRAVIA TV is available on the same network.
- **SC-002**: In a normal home network with one compatible BRAVIA TV available, the app presents a discovered-device result within 15 seconds for at least 90% of scan attempts during validation.
- **SC-003**: Users can cancel an active scan and return to the setup entry state within 1 second.
- **SC-004**: Users can recover from a no-devices result by either retrying scan or choosing manual IP entry without restarting the app.
- **SC-005**: After a successful connection, a later app launch restores the remembered TV without requiring the user to repeat setup.
- **SC-006**: The discovery flow remains usable when no devices are found, with clear guidance that helps users check TV power, same Wi-Fi, and TV network-control permissions.

## Assumptions

- "brivia" in the user request refers to Sony BRAVIA devices.
- The target device class is Sony BRAVIA TVs on the same local network as the iPhone.
- Manual IP setup remains available as a fallback and is not replaced by automatic discovery.
- Pairing or authorization, if required by a discovered TV, should be handled as part of connection readiness or existing connection setup behavior.
- Automatic discovery is now in scope for this feature even though the earlier v1 design document listed it as a non-goal.
- Real-device validation is required before claiming the full discovery chain works end to end.
