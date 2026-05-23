# SonyRemoteController App Design

This document is the UI and interaction source of truth for v1.

The v1 app is a native, simple, one-handed iPhone remote for compatible TV. It
supports automatic TV discovery, manual IP + PSK fallback setup, a core TV
remote layout, a dedicated settings page, and layered connection error guidance.

## Product Goals

- Make the first usable version feel like a real remote, not a setup demo.
- Keep the main screen focused on controlling the TV.
- Let users automatically discover a compatible TV on the local network.
- Let users manually configure a compatible TV with IP address and Pre-Shared Key
  when discovery is unavailable.
- Save the PSK securely in Keychain.
- Explain connection failures well enough for users to fix common TV or network
  setup problems.

## V1 Non-Goals

- Multiple device switching.
- Wake-on-LAN.
- Input source switching.
- App launching.
- Numeric keypad, color keys, playback controls, or advanced service commands.
- Custom image assets, custom brand illustrations, or skeuomorphic remote skins.
- Dedicated iPad, landscape, or split-view layouts.

## Design Principles

- Use native SwiftUI controls, SF Symbols, system colors, and system material.
- Design for portrait iPhone and one-handed operation.
- Keep the remote page as the app's primary surface.
- Put setup and troubleshooting details in a separate settings page.
- Make disabled and failed states explicit rather than silently ignoring taps.
- Support Dynamic Type and VoiceOver from the first implementation.

## Information Architecture

The app has two v1 screens.

```text
Auto Connect Flow
  First Launch
  Scanning
  Devices Found
  Connecting
  Connected Ready
  No Devices
  Clear Connection Confirmation

Remote Page
  Connection Header
  Error Banner
  Remote Pad
  Volume Controls
  Connect CTA

Device Settings Page
  Device Form
  Connection Requirements
  Test Connection
  Save
  Error Guidance
```

### Auto Connect Flow

The auto connect flow is the first screen when no usable TV is configured.

It follows the Figma frames:

- `02A Auto Connect - First Launch`
- `02B Auto Connect - Scanning`
- `02C Auto Connect - Devices Found`
- `02D Auto Connect - Connecting`
- `02E Auto Connect - Connected`
- `02F Auto Connect - No Devices`
- `02G Auto Connect - Clear Confirmation`

The flow contains:

- App title `TV Remote Control`.
- First-launch title `连接 TV 电视`.
- Primary action `扫描附近设备`.
- Secondary action `手动输入 IP`.
- Scanning title `正在扫描附近设备` with cancel action.
- Device selection title `选择要连接的电视`.
- Connecting title `正在连接电视`.
- Connected ready state with `进入遥控器`.
- No devices state with retry, manual IP entry, and troubleshooting guidance.

### Remote Page

The remote page is the first screen and the normal daily-use surface.

It contains:

- Top connection header with device name or IP, connection state, and settings
  entry.
- Optional error banner for the latest connection or command failure.
- Core remote pad with directional buttons and Confirm.
- Utility buttons for Home, Back, Power, Volume Up, Volume Down, and Mute.
- Connect action when no usable device is configured.

The remote page should not include a marketing hero or diagnostic checklist.
Network scanning and device lists belong to the auto connect flow before the
remote page is ready.

### Device Settings Page

The settings page owns TV configuration and connection validation.

It contains:

- TV name field.
- IP address field.
- PSK secure field.
- Test Connection button.
- Save button.
- Short requirements block:
  - TV and iPhone must be on the same local network.
  - TV IP Control must be enabled.
  - Pre-Shared Key authentication must be enabled and match the entered PSK.
  - Remote Device Control must be enabled.

Use a navigation presentation that fits the app structure. For v1, a
`NavigationStack` push from the remote page is preferred because setup is a full
task with validation and explanatory content.

## Page States

Every page state must map to explicit State fields in the architecture layer.

### No Device

No saved TV exists.

- Header title: `No TV Connected`.
- Header detail: `Add a compatible TV to start`.
- Remote controls are disabled.
- Primary action: `Connect a compatible TV`.
- Settings entry remains visible.

### Disconnected

A saved TV exists, but the app is not currently connected or verified.

- Header shows the saved TV name and IP.
- Detail text: `Disconnected`.
- Remote controls are disabled until connection is verified.
- Primary action: `Reconnect` or settings entry.

### Connecting

The app is testing or restoring the connection.

- Header shows `Connecting...`.
- Test/Save actions show progress and prevent duplicate submits.
- Remote controls are disabled.

### Connected

The TV connection has been verified.

- Header shows TV name or IP.
- Detail text: `Connected`.
- Remote controls are enabled.
- Command taps provide subtle pressed feedback.

### Failed

The latest connection attempt or command failed.

- Header remains tied to the best known device state.
- Error banner appears with a short user-facing message.
- Settings page shows a more specific recovery suggestion when available.
- Remote controls are disabled for connection failures and remain enabled only
  for transient command failures where the device is still considered connected.

## Components

### Connection Header

Purpose: summarize whether the app can control the TV.

Content:

- Device title: saved TV name, IP address, or `No TV Connected`.
- Status detail: no device, disconnected, connecting, connected, or failed.
- Settings button using a gear SF Symbol.

Behavior:

- Tapping settings opens Device Settings Page.
- Header text must fit compact iPhone widths without overlapping the settings
  button.

Accessibility:

- Settings button label: `TV Settings`.
- Header should be readable as one status summary.

### Error Banner

Purpose: expose actionable failure information without taking over the remote
page.

Content:

- Short title.
- One-sentence recovery guidance.
- Optional button to open settings when the fix requires configuration.

Error mapping:

- Invalid IP: `Enter a valid IP address.`
- Timeout or unreachable: `Check that your iPhone and TV are on the same network and that the TV is awake.`
- Unauthorized: `Check the Pre-Shared Key configured on the TV.`
- Remote control unavailable: `Enable IP Control and Remote Device Control on the TV.`
- Unknown: `The TV did not respond as expected. Try again or check the TV settings.`

Accessibility:

- Banner should be announced when it appears after a user action.

### Remote Pad

Purpose: provide the core directional remote.

Buttons:

- Up.
- Down.
- Left.
- Right.
- Confirm.

Layout:

- Use a stable square area.
- Center Confirm in the middle.
- Directional buttons surround Confirm.
- Buttons should not shift size when disabled or pressed.

Interaction:

- Disabled when there is no verified connection.
- Tap sends one command.
- No repeat-on-hold behavior in v1.

Accessibility:

- Minimum touch target: 44 x 44 points.
- VoiceOver labels: `Up`, `Down`, `Left`, `Right`, `Confirm`.

### Utility Controls

Purpose: expose the v1 non-directional remote commands.

Buttons:

- Power.
- Home.
- Back.
- Volume Up.
- Volume Down.
- Mute.

Layout:

- Keep Power visually separate from everyday navigation controls.
- Place Home and Back near the remote pad.
- Place Volume Up, Volume Down, and Mute together.

Accessibility:

- Use SF Symbols where available, with explicit labels.
- Disabled state must be visually clear and VoiceOver must report disabled.

### Device Settings Form

Purpose: collect and validate the manual TV connection.

Fields:

- TV name: optional display name.
- IP address: required.
- PSK: required secure input.

Validation:

- IP address must be non-empty and syntactically valid before testing.
- PSK must be non-empty before testing or saving.
- Save requires a successful test connection in v1.

Actions:

- `Test Connection`: validates fields and verifies the TV.
- `Save`: persists metadata and stores PSK in Keychain after successful test.

Accessibility:

- Fields must have labels visible on screen.
- Error text must be associated with the relevant field or form section.
- Buttons must keep readable labels at larger Dynamic Type sizes.

## Interaction Flows

### First Launch

1. App opens on Remote Page.
2. State is `no device`.
3. Remote controls are disabled.
4. User taps `Connect a compatible TV`.
5. App opens Device Settings Page.

### Test Connection

1. User enters TV name, IP address, and PSK.
2. User taps `Test Connection`.
3. Settings state becomes `connecting`.
4. App validates local input.
5. App calls the TV test endpoint.
6. Success shows connected confirmation and enables `Save`.
7. Failure shows layered error guidance.

### Save Device

1. User has a successful connection test.
2. User taps `Save`.
3. App stores PSK in Keychain.
4. App stores non-sensitive device metadata outside Keychain.
5. App returns to Remote Page.
6. Remote Page enters `connected`.

### Send Remote Command

1. User taps an enabled remote button.
2. Remote Pad View calls its ViewModel intent method.
3. ViewModel sends the mapped TV command.
4. On success, the pressed state clears without additional navigation.
5. On failure, Error Banner appears with a mapped recovery message.

### Recover From Failure

1. Error Banner appears after connection or command failure.
2. User taps settings when the issue is configuration-related.
3. Device Settings Page pre-fills saved non-sensitive metadata.
4. PSK is loaded from Keychain only for connection use, not displayed as plain
   text.
5. User can re-enter PSK and test again.

## Accessibility Requirements

- All tappable controls must have at least a 44 x 44 point hit target.
- Icon-only buttons must have explicit accessibility labels.
- Disabled controls must expose disabled state to accessibility.
- Remote buttons must remain reachable and readable with Dynamic Type.
- Form fields must have visible labels, not placeholder-only labels.
- Error messages must be concise and announced after user-triggered failures.
- Do not rely only on color to communicate connection state or errors.

## Implementation Notes

- Do not introduce custom bitmap assets for v1.
- Do not depend on AccentColor for core usability.
- Use system spacing and native materials before introducing a design system.
- Keep remote control dimensions stable with explicit frames or layout
  constraints.
- If the UI outgrows the app target, extract reusable visual primitives only
  after the first implementation proves the boundary.
