# Data Model: Remote command visual stability

## RemotePageState

Represents the Remote Page UI state tree.

**Fields involved**:

- `connection: ConnectionHeaderState`
- `settings: DeviceSettingsState`
- `remotePad: RemotePadState`
- `savedDevice: SonyDevice?`
- `status: ConnectionStatus`
- `error: RemoteControlError?`
- `isSettingsPresented: Bool`
- `canSendCommands: Bool`

**Validation rules**:

- `status` describes the best known connection state, not transient command-send progress.
- `error` may show the latest command failure while `status` remains `.connected` for transient command failures.
- `canSendCommands` remains derived from `status.allowsRemoteCommands`.

**State transition constraints**:

- Successful command send must not change `status`, `connection.title`, `connection.subtitle`, `savedDevice`, or `isSettingsPresented`.
- Transient command failure must set `error` to the mapped command error without changing connection header identity or disabling remote controls unless the failure is explicitly treated as a connection failure.

## ConnectionHeaderState

Represents visible title/subtitle content for the top Remote Page header.

**Fields involved**:

- `title: String`
- `subtitle: String`

**Validation rules**:

- Header fields change when the saved device or connection status changes.
- Header fields do not change solely because a remote command is in flight.

## RemotePadState

Represents command-specific UI state for the remote pad and utility controls.

**Fields involved**:

- `isEnabled: Bool`
- `lastCommand: RemoteCommand?`
- `isSendingCommand: Bool`

**Validation rules**:

- `isEnabled` follows `RemotePageState.status.allowsRemoteCommands`.
- `isSendingCommand` is scoped to command progress and must return to `false` after success or failure.
- `lastCommand` records the last successfully sent command only.

**State transitions**:

```text
Idle enabled
  -> Sending command
  -> Idle enabled with lastCommand updated on success
  -> Idle enabled with page error updated on transient failure

Idle disabled
  -> Missing-device error when send is attempted defensively
```

## RemoteCommand

Represents a user-triggered Sony remote action.

**Fields involved**:

- Command identity from `SonyRemoteCore.RemoteCommand`
- IRCC code mapping in shared package tests

**Validation rules**:

- Command mapping remains unchanged by this feature.
- Command serialization/networking remains owned by `SonyRemoteNetworking`.

## Command Failure

Represents a failure returned by repository PSK lookup or BRAVIA command send.

**Fields involved**:

- `RemoteControlError` mapped into `RemotePageState.error`

**Validation rules**:

- Failure must surface through the existing error banner state.
- Failure must not trigger a full page reset or unintended connection header update.
