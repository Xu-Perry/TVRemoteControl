# Contract: Remote command visual stability

This contract describes expected Remote Page behavior for command sends. It is a UI/state contract for the iOS app, not a network API contract.

## Connected Command Success

**Given** the Remote Page has a saved device and `status == .connected`
**When** the user taps a remote command button and the command send succeeds
**Then**:

- The command is dispatched exactly once through the BRAVIA command service.
- `RemotePadState.isSendingCommand` returns to `false`.
- `RemotePadState.lastCommand` becomes the sent command.
- `RemotePageState.status` remains `.connected`.
- `ConnectionHeaderState.title` and `ConnectionHeaderState.subtitle` remain unchanged.
- `RemotePadState.isEnabled` remains `true`.
- No full-page visual reset, flash, or layout jump is visible.

## Connected Command Failure

**Given** the Remote Page has a saved device and `status == .connected`
**When** the user taps a remote command button and the command send fails transiently
**Then**:

- `RemotePadState.isSendingCommand` returns to `false`.
- `RemotePadState.lastCommand` is not updated for the failed command.
- `RemotePageState.error` is set to the mapped `RemoteControlError`.
- `RemotePageState.status` remains tied to the best known connection state unless the implementation explicitly determines that the connection state changed.
- The connection header, remote pad, and utility controls remain mounted and visually stable.
- The existing error banner pattern presents the failure.

## Disabled Remote Defensive Send

**Given** the Remote Page is not allowed to send commands
**When** command send is invoked defensively
**Then**:

- No network command is dispatched.
- The user receives the existing missing-device or disabled-state feedback.
- Remote controls remain disabled.

## Manual Smoke Contract

Real-device validation must verify:

- Repeated taps on directional commands do not flash the entire Remote Page.
- Repeated taps on utility commands do not flash the entire Remote Page.
- Header and controls do not jump or remount while command sends are in flight.
- Command failure still displays the layered error banner.
