# Contract: TV Auto Discovery Flow

## UI State Contract

The app must expose these user-visible states for the auto-connect flow:

| State | Required User Action | Required Feedback | Exit Conditions |
|-------|----------------------|-------------------|-----------------|
| First launch | Scan nearby devices or choose manual IP entry | Explains that TV TVs must be on the same network | Scan starts, or manual entry opens |
| Scanning | Cancel | Shows active scan progress | Devices found, no devices found, failure, or cancel |
| Devices found | Select a TV or rescan | Lists deduplicated TV TVs with names and readiness labels | Connection starts or scan restarts |
| Connecting | Cancel connection when available | Shows selected TV and connection progress | Connected-ready, failure, or cancellation |
| Connected-ready | Enter remote or clear connection | Confirms the selected TV is ready | Remote opens or clear confirmation appears |
| No devices | Retry scan or choose manual IP entry | Shows same-network, TV power, and TV permission guidance | Scan restarts or manual entry opens |
| Clear confirmation | Confirm or cancel | Describes that the remembered connection will be removed | Connection cleared or previous state restored |

## Discovery Service Contract

The discovery boundary must support:

- Start a new discovery session.
- Emit discovered TV device candidates during or at the end of the scan.
- Deduplicate candidates by stable identity or normalized network location.
- Complete with `devicesFound` when at least one TV TV is available.
- Complete with `noDevices` when the scan finishes without a TV TV.
- Cancel an active scan so later callbacks do not update the visible session.
- Report recoverable failures without requiring app restart.

The service contract must be testable with fixtures and fakes. Unit tests must not require a real TV or local-network access.

## Connection Contract

The auto-connect flow must:

- Start connection only after the user selects one discovered TV.
- Show progress tied to that selected TV.
- Use the same connection verification expectations as the existing manual setup path.
- Persist a successful device so it becomes the remembered TV.
- Keep manual IP entry available when discovery or connection fails.
- Avoid replacing or clearing an existing remembered TV unless the user confirms the clear action.

## Persistence Contract

Remembered TV metadata must:

- Store enough information to restore the TV on future launches.
- Keep PSK secret material in the existing secure store boundary.
- Support clearing the remembered TV after confirmation.
- Preserve recoverable error states when metadata exists but secret material is missing.

## Test Contract

Automated coverage must include:

- Device description parsing and TV filtering.
- Deduplication of repeated discovery candidates.
- Scan cancellation ignoring stale results.
- Retry from no-devices and devices-found states.
- Selecting a discovered TV transitions into connecting.
- Successful connection persists and restores the TV.
- Missing PSK or unreachable TV shows recoverable error state.

Manual smoke coverage must include:

- Real TV discovery on the same Wi-Fi.
- Successful connection from discovered-device list.
- Relaunch restore into the remembered TV.
- No-devices recovery guidance when TV/network prerequisites are intentionally broken.
