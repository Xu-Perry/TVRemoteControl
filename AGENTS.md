# SonyRemoteController Agent Guide

This repository contains an iOS app for controlling Sony devices. The app is
expected to be built with SwiftUI, Observation, MVVM, and Swift Package Manager
based modularization.

## Project Direction

- Build the product as a real app first, not as a demo screen collection.
- Prefer SwiftUI-native flows and state management.
- Use the Observation framework for UI `State`. Do not introduce
  Combine-based `ObservableObject` / `@Published` patterns unless a dependency
  explicitly requires them.
- Keep networking, device discovery, protocol parsing, and UI presentation in
  separate layers.
- Use Swift Package Manager for feature and domain modules once a boundary is
  stable enough to justify extraction.

## Architecture

Detailed architecture rules live in
[docs/AppArchitecture.md](docs/AppArchitecture.md). Follow that document as the
source of truth for the SwiftUI + Observation + MVVM pattern in this project.
UI and interaction rules live in [docs/AppDesign.md](docs/AppDesign.md). Follow
that document before local visual preference when implementing app screens.

Use MVVM with these responsibilities:

- `View`: SwiftUI layout, user interactions, navigation presentation, and view
  composition only.
- `State`: observable UI state and display data only. It should not contain
  business logic or side effects.
- `ViewModel`: user-intent handling, async task orchestration, validation, side
  effects, and mutation of `State`.
- `Model` / domain types: Sony device entities, remote commands, connection
  state, request/response payloads, and pure business rules.
- `Service` / client types: network transport, SSDP/discovery, device APIs,
  persistence, and system integrations.

State objects should be annotated with `@Observable` and should usually be
`@MainActor` when they drive UI state. View models that mutate UI state should
also be main-actor isolated.

Views should read `State` and call `ViewModel` intent methods. They should not
mutate shared `State` directly. Page-level view models own child view models and
coordinate communication between child components.

Prefer dependency injection through initializers. Avoid global mutable singletons
for services unless they wrap a true process-wide system resource and expose a
testable protocol.

## Suggested Module Boundaries

Start simple in the app target. When code grows, extract SPM packages along
clear ownership boundaries, for example:

- `SonyRemoteCore`: domain models, commands, device capabilities, shared errors.
- `SonyRemoteNetworking`: HTTP/JSON-RPC transport, discovery, request signing or
  pairing APIs if needed.
- `SonyRemotePersistence`: saved devices, preferences, credentials or tokens.
- `SonyRemoteFeatures`: feature-level SwiftUI screens and view models, if the
  app target becomes too large.
- `SonyRemoteDesign`: reusable controls, symbols, spacing, colors, and haptics.

Package targets should avoid importing the app target. Lower-level packages
should not depend on feature UI packages.

Open source SDK candidates and dependency intake rules are tracked in
[docs/OpenSourceSDKs.md](docs/OpenSourceSDKs.md). Do not add a third-party
package without updating that document with the decision and rationale.

## File Organization

Within each module or target, prefer feature-oriented folders:

```text
FeatureName/
  FeatureNameState.swift
  FeatureNameView.swift
  FeatureNameViewModel.swift
  FeatureNameModels.swift
  FeatureNameTests.swift
```

Shared infrastructure can live under names like `Networking`, `Discovery`,
`Persistence`, `DesignSystem`, and `TestingSupport`.

Keep file names aligned with the primary type they contain.

## SwiftUI Guidelines

- UI implementation should follow [docs/AppDesign.md](docs/AppDesign.md) before
  local component preference.
- Keep views small and composable, but do not split purely for line count.
- Put business decisions in view models or domain helpers, not in view bodies.
- Use `@State` for view-local transient state.
- Use `@Bindable` only when a view needs explicit two-way binding into an
  `@Observable` state object.
- Use previews with lightweight mock data for non-trivial views.
- Avoid stringly typed navigation where a typed route enum would be clearer.
- Prefer SF Symbols for standard remote-control icons when available.

## Observation Guidelines

- Prefer `@Observable` classes for mutable UI state.
- Mark derived values as computed properties when they can be cheaply derived.
- Use `@ObservationIgnored` for dependencies, cancellables, clocks, loggers, or
  other implementation details that should not trigger view updates.
- Keep async state transitions explicit: loading, loaded, empty, failed,
  disconnected, pairing, connected, and similar states should be representable.

## Concurrency

- Use Swift concurrency (`async` / `await`) for network and discovery work.
- Keep UI state mutation on the main actor.
- Store long-running tasks when they need cancellation, especially scanning,
  pairing, polling, and command-repeat interactions.
- Do not block the main thread for network discovery or device requests.

## Testing

The project currently uses Swift Testing (`import Testing`). Prefer it for new
unit tests.
Manual real-device verification steps live in
[docs/ManualSmokeTest.md](docs/ManualSmokeTest.md).

Add focused tests for:

- Command mapping and serialization.
- Device discovery parsing.
- View model state transitions.
- Error handling and retry behavior.
- Persistence migrations or encoding/decoding.

Use test doubles for networking and discovery. Tests should not require a real
Sony device or local network access unless they are explicitly marked as manual
or integration tests.

## Commands

Use Xcode or `xcodebuild` for verification. A typical command is:

```sh
xcodebuild test -scheme SonyRemoteController -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

If the simulator name is unavailable locally, list destinations first and choose
an installed iOS simulator.

## Coding Style

- Follow the surrounding Swift style.
- Prefer clear type names over abbreviations.
- Keep access control as narrow as practical.
- Avoid broad refactors while implementing a focused change.
- Do not add third-party dependencies without a clear reason.
- If a dependency is needed, prefer adding it through Swift Package Manager and
  documenting why it belongs in the selected module and in
  [docs/OpenSourceSDKs.md](docs/OpenSourceSDKs.md).

## Git And Generated Files

- Do not revert user changes unless explicitly asked.
- Keep Xcode project changes minimal and reviewable.
- Do not commit derived data, build products, or local user state.
- Be careful with `xcuserdata`; only keep changes that are intentionally part of
  the project workflow.

## Agent Workflow

Before changing behavior:

1. Inspect the current target, package, and test layout.
2. Identify the smallest module or file set that owns the change.
3. Add or update tests when behavior changes.
4. Run the relevant test target when feasible.
5. Summarize changed files and verification results.

When adding a new feature, first decide whether it belongs in the app target or
an SPM package. Default to the app target until a stable reusable boundary is
clear.
