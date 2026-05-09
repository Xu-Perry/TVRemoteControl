# SonyRemoteController Agent Guide

This repository contains an iOS app for controlling Sony devices. The app is
expected to be built with SwiftUI, Observation, MVVM, and Swift Package Manager
based modularization.

## Project Direction

- Build the product as a real app first, not as a demo screen collection.
- Use SwiftUI, Observation, MVVM, and Swift Package Manager.
- Keep constitution rules in [.specify/memory/constitution.md](.specify/memory/constitution.md).
- Keep implementation details in the docs linked below.

## Architecture

Use [docs/AppArchitecture.md](docs/AppArchitecture.md) as the implementation
guide for SwiftUI + Observation + MVVM. It defines the concrete responsibilities
for `View`, `State`, `ViewModel`, services, repositories, child view models, and
SPM module extraction.

Use [docs/AppDesign.md](docs/AppDesign.md) as the source of truth for UI and
interaction behavior before local visual preference.

## Suggested Module Boundaries

Start in the app target unless [docs/AppArchitecture.md](docs/AppArchitecture.md)
identifies a stable package boundary. Existing local packages are under
`Packages/SonyRemoteModules`.

Dependency intake is tracked in [docs/OpenSourceSDKs.md](docs/OpenSourceSDKs.md).
Do not add a third-party package without updating that document.

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

Follow the Observation examples in [docs/AppArchitecture.md](docs/AppArchitecture.md).
Use `@Observable` state objects for mutable UI state and keep async state
transitions explicit.

## Concurrency

- Use Swift concurrency (`async` / `await`) for network and discovery work.
- Keep UI state mutation on the main actor.
- Store long-running tasks when they need cancellation, especially scanning,
  pairing, polling, and command-repeat interactions.
- Do not block the main thread for network discovery or device requests.

## Testing

The project uses Swift Testing (`import Testing`) for unit tests. Prefer it for
new unit coverage.
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

Read [README.md](README.md) for build and tests.

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

## UI Design
- Use `figma-use` cli check the ui design of view, follow it.
- All icons can be find in SF symbols.

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

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan:
[specs/003-restore-app-pages/plan.md](specs/003-restore-app-pages/plan.md)
<!-- SPECKIT END -->
