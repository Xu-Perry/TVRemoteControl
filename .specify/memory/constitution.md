<!--
Sync Impact Report
Version change: 2.0.0 -> 2.1.0
Modified principles: Architecture Boundary expanded with one-class-per-file rule
Added sections: none
Removed sections: none
Templates requiring updates:
- .specify/templates/plan-template.md: updated
- .specify/templates/spec-template.md: reviewed, no change
- .specify/templates/tasks-template.md: reviewed, no change
- .specify/templates/checklist-template.md: reviewed, no change
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

## Governance

This constitution defines why the project is built this way and what is not
allowed. Practical implementation instructions belong in `AGENTS.md` and
project documents. Amendments require updating this file and any affected
Spec Kit templates in the same change.

Versioning follows semantic versioning: MAJOR for incompatible principle
changes, MINOR for new or expanded principles, and PATCH for wording
clarifications.

**Version**: 2.1.0 | **Ratified**: 2026-04-30 | **Last Amended**: 2026-04-30
