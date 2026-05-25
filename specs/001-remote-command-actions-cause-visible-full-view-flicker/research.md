# Research: Remote command actions cause visible full-view flicker

## Decision: Keep command-send progress local to remote pad state

**Rationale**: The reported flicker happens during command sends, while the connection header and page layout should remain stable. The current architecture already has `RemotePageState.remotePad` for command-specific UI state, so transient progress should not be represented as a page-level connection status or any broad state that forces unrelated page sections to change.

**Alternatives considered**:

- Mutate `RemotePageState.status` to a command-in-progress state: rejected because connection status should describe TV connection, not command activity, and changing it can affect header, enabled state, and conditional page content.
- Add a separate global loading overlay: rejected because the design requires subtle local button feedback and stable controls, not a full-page visual mode.

## Decision: Preserve connected status on transient command failures

**Rationale**: App design states that remote controls remain enabled for transient command failures where the device is still considered connected. A command failure should update the layered error message while keeping the best known connection header and remote layout stable.

**Alternatives considered**:

- Treat every command failure as a connection failure: rejected because it disables controls and changes the header even when the underlying device may still be reachable.
- Suppress command errors to avoid flicker: rejected because the issue acceptance criteria require the proper layered error message.

## Decision: Avoid view identity churn and broad implicit animation during command sends

**Rationale**: SwiftUI flicker can be caused by conditional content insertion/removal, changing identity, or implicit animations around broad page state. The Remote Page should keep the connection header, remote pad, and utility controls mounted across command sends. Only button pressed/progress affordances and the error banner should change.

**Alternatives considered**:

- Rebuild Remote Page sections based on command progress: rejected because it risks the full-view reset described in the issue.
- Disable all animations on the page: rejected as too broad; button pressed feedback should remain subtle and local.

## Decision: Add focused ViewModel/state tests and keep real-device visual validation manual

**Rationale**: Unit tests can verify that command sends do not mutate connection status, header title/subtitle, or remote enabled state unnecessarily, and that failures still set the page error. The visible flicker itself must be verified through the real-device smoke path because it depends on actual SwiftUI rendering behavior on hardware.

**Alternatives considered**:

- UI snapshot tests only: rejected because the current project uses Swift Testing for unit coverage and has no snapshot infrastructure.
- Real-device-only validation: rejected because state regression risks can be tested deterministically without a TV.

## Decision: Keep implementation in the app target

**Rationale**: The behavior is Remote Page presentation/state orchestration. Shared package modules already cover command mapping and networking; no reusable package boundary is introduced by this fix.

**Alternatives considered**:

- Move remote pad state/view model into `Packages/TVRemoteModules`: rejected because this issue is screen-specific and not yet a stable reusable module boundary.
- Add a third-party state-management dependency: rejected because the existing SwiftUI + Observation + MVVM architecture is sufficient and dependency intake would be unjustified.
