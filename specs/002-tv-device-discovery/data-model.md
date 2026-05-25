# Data Model: TV Device Auto Discovery

## DiscoveredTVDevice

Represents a TV TV found during local-network discovery.

Fields:

- `id`: Stable identity for this discovery result, derived from a unique device identity when available, otherwise from normalized network location.
- `name`: User-facing device name, falling back to network address when the TV does not provide a friendly name.
- `host`: Network address used for connection.
- `port`: Control port, defaulting to the existing TV control port when discovery metadata does not provide one.
- `uniqueIdentifier`: Optional stable device identifier from discovery metadata.
- `connectionReadiness`: Whether the app knows the device is connectable, already paired, unavailable, or unknown.
- `lastSeenAt`: Timestamp used to keep scan results current and avoid stale presentation.

Validation rules:

- `host` must be non-empty and normalized before display or connection.
- Duplicate results with the same unique identity or normalized host must collapse to one row.
- `name` must be safe for compact display; empty or whitespace-only names fall back to `host`.

## DiscoverySession

Represents one user-started scan.

Fields:

- `id`: Unique session identity used to ignore stale results.
- `state`: `idle`, `scanning`, `devicesFound`, `noDevices`, `cancelled`, or `failed`.
- `devices`: Current ordered list of discovered TV devices.
- `startedAt`: Scan start time.
- `completedAt`: Completion time when the scan finishes, is cancelled, or fails.
- `message`: Optional user-facing recovery message.

State transitions:

```text
idle -> scanning
scanning -> devicesFound
scanning -> noDevices
scanning -> cancelled
scanning -> failed
devicesFound -> scanning
noDevices -> scanning
cancelled -> idle
failed -> scanning
```

Validation rules:

- Only the active session may update visible scan results.
- Cancellation must prevent later results from the cancelled session from changing UI state.
- Retry starts a new session and clears stale transient errors.

## AutoConnectState

Represents the setup and connection flow shown before the remote is ready.

Fields:

- `screen`: `firstLaunch`, `scanning`, `devicesFound`, `connecting`, `connectedReady`, `noDevices`, or `clearConfirmation`.
- `discoverySession`: Current discovery session state.
- `selectedDevice`: Device selected for connection.
- `rememberedDevice`: Saved TV connection, when one exists.
- `connectionError`: Optional user-facing connection failure.
- `isManualEntryPresented`: Whether the manual IP fallback is active.

State transitions:

```text
firstLaunch -> scanning
scanning -> devicesFound
scanning -> noDevices
devicesFound -> connecting
connecting -> connectedReady
connectedReady -> remote
noDevices -> scanning
noDevices -> manualEntry
connectedReady -> clearConfirmation
clearConfirmation -> firstLaunch
```

Validation rules:

- `connecting` requires a selected device.
- `connectedReady` requires a successful connection and a remembered device.
- Clearing a remembered device requires explicit confirmation.

## RememberedTVConnection

Represents the TV the app should restore on later launches.

Fields:

- `device`: Existing saved `TVDevice` metadata.
- `pskReference`: Existing secure reference used to load the PSK.
- `lastConnectedAt`: Last successful connection time.
- `source`: `manual` or `discovery`.

Validation rules:

- PSK secret material must stay in the secure store and must not be duplicated into plain metadata.
- Restoring a remembered TV must fail into a recoverable state when the PSK is missing or the TV is unreachable.

## ConnectionAttempt

Represents an attempt to connect one selected discovered TV.

Fields:

- `device`: Selected discovered TV.
- `state`: `idle`, `connecting`, `succeeded`, `failed`, or `cancelled`.
- `startedAt`: Connection start time.
- `completedAt`: Completion time.
- `failureReason`: Optional user-facing failure category.

Validation rules:

- A new connection attempt cancels or supersedes any previous attempt.
- Success persists the TV before the user enters the remote.
- Failure does not remove an existing remembered device unless the user explicitly clears it.
