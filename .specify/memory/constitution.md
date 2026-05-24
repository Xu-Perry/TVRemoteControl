<!--
Sync Impact Report
Version change: 2.1.0 -> 2.2.0
Modified principles: none
Added sections: III. Responsive Page Layout
Removed sections: none
Templates requiring updates:
- .specify/templates/plan-template.md: updated
- .specify/templates/spec-template.md: reviewed, no change
- .specify/templates/tasks-template.md: reviewed, no change
- .specify/templates/checklist-template.md: reviewed, no change
- docs/AppDesign.md: updated
Follow-up TODOs: none
-->

# SonyRemoteController Constitution

## Core Principles

### I. Architecture Boundary
The app uses SwiftUI, Observation, and MVVM so each layer has one reason to
change. This keeps UI rendering, state mutation, coordination, networking, and
persistence reviewable and testable.

Features MUST NOT put business logic, network calls, persistence, or command
dispatch in SwiftUI views. Views MUST NOT mutate shared UI state directly.
Child view models MUST NOT coordinate through sibling child view models.
Cross-component coordination belongs in the page view model.
Each class MUST live in its own source file. A source file SHOULD NOT define
multiple classes.

### II. Test-Driven Change
Behavior changes need executable confidence before they become product code.
Tests protect device protocol mapping, persistence, error handling, and view
model state transitions from regressions that are hard to catch manually.

Changes MUST NOT ship without focused automated tests when the behavior can be
tested without a real TV. Real-device or local-network behavior MUST have a
documented manual smoke path when automation is not practical. Tests MUST NOT
depend on a real BRAVIA TV unless they are explicitly marked as manual or
integration-only.

### III. Responsive Page Layout
Every app page must remain usable across supported portrait iPhone sizes,
Dynamic Type settings, safe-area changes, and keyboard presentation. Responsive
layout keeps the remote and setup flows reliable on compact screens instead of
only matching one simulator size.

Page UI MUST use SwiftUI responsive layout primitives, content-driven sizing,
safe-area-aware placement, and scrolling where content can exceed the viewport.
Pages MUST NOT rely on fixed absolute frames, hard-coded screen coordinates, or
single-device spacing assumptions for primary layout. Fixed dimensions are
allowed only for intrinsically fixed controls, icons, or hit targets, and they
MUST be bounded by adaptive containers so small screens do not clip, overlap, or
hide required actions.

## Governance

This constitution defines why the project is built this way and what is not
allowed. Practical implementation instructions belong in `AGENTS.md` and
project documents. Amendments require updating this file and any affected
Spec Kit templates in the same change.

Versioning follows semantic versioning: MAJOR for incompatible principle
changes, MINOR for new or expanded principles, and PATCH for wording
clarifications.

**Version**: 2.2.0 | **Ratified**: 2026-04-30 | **Last Amended**: 2026-05-24
