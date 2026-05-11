# Research: Figma App Page Restoration

## Decision: Treat Figma as the source of truth for restored page structure

**Rationale**: The user explicitly asked to fetch the latest design with `figma-use` and restore the main page plus other pages. Current `figma-use status` confirms the active file is `BRAVIA Controller UI Kit`, and `figma-use query "//FRAME"` confirms the relevant frames are present: `01 Main Remote`, `03 Input Source Sheet`, `04 Keyboard Input`, `05 More Keys Sheet`, `06 Settings`, and `07 Design Tokens`.

**Alternatives considered**:
- Follow current `docs/AppDesign.md` only: rejected because it still contains earlier v1 non-goals for input source and numeric keypad that the latest Figma now supersedes for this feature.
- Reuse the current simplified remote page as-is: rejected because it does not match the requested Figma restoration.

## Decision: Keep implementation in the app target

**Rationale**: The restoration is mostly page composition, presentation state, settings UI, and local view model coordination under `SonyRemoteController/Remote/`. The existing packages already hold reusable command and networking boundaries. Creating a new package for Figma-specific UI would add module overhead without a stable reusable surface.

**Alternatives considered**:
- Extract a `RemoteUI` package immediately: rejected because the feature is still tightly coupled to app navigation and Figma-backed product flow.
- Put all behavior inside views: rejected by the constitution and `docs/AppArchitecture.md`; state mutation and side effects belong in view models.

## Decision: Model secondary controls as explicit remote page presentation state

**Rationale**: Input source and more keys are bottom sheets, keyboard input is an input bar above the system keyboard on the main remote page, and settings remains a page navigation flow. Explicit presentation state gives tests a stable contract and prevents view-only boolean drift.

**Alternatives considered**:
- Use unrelated local view `@State` for each presentation: rejected because secondary-page transitions are user-visible product behavior and need test coverage.
- Use stringly typed navigation identifiers: rejected because a typed enum or explicit state fields are clearer and safer.

## Decision: Keep `关于` rows visible but inactive

**Rationale**: The user stated the settings page `关于` content has no destination yet and can temporarily avoid navigation. The planned behavior is that `帮助与反馈`, `隐私政策`, and `关于应用` remain visible in the settings design but tapping them does not open an empty or broken page.

**Alternatives considered**:
- Hide the rows: rejected because Figma shows the section and the user asked to restore the page.
- Navigate to placeholder pages: rejected because placeholder destinations would look unfinished and contradict the request.

## Decision: Prefer app-level Swift Testing for behavior and manual/screenshot checks for visual parity

**Rationale**: State transitions, no-op rows, keyboard draft mutation, preference toggles, and command dispatch can be tested without a TV. Exact visual parity requires rendering on simulator and comparing against Figma frames, which is better captured in quickstart/manual validation than in brittle unit tests.

**Alternatives considered**:
- Require a real TV for all restored pages: rejected because most behavior is UI state and command intent routing.
- Add only manual testing: rejected because navigation and state behavior can regress and is practical to automate.
