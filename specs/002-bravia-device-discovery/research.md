# Research: BRAVIA Device Auto Discovery

## Decision: Use native Apple networking facilities for discovery

**Rationale**: The existing dependency record says to prefer Apple frameworks and specifically evaluate `Network.framework` when automatic discovery or UDP behavior is needed. This feature needs local-network discovery but not enough breadth to justify adding a socket dependency.

**Alternatives considered**:

- Third-party socket package: rejected because native APIs should be attempted first and the dependency document recommends avoiding new packages until native implementation cost is proven high.
- Manual IP only: rejected because the feature requirement is to run the automatic discovery flow end to end.

## Decision: Model discovery as SSDP/UPnP-style local-network discovery with BRAVIA filtering

**Rationale**: BRAVIA TVs expose local-network control surfaces and the current architecture already names a discovery service and SSDP parsing as recommended boundaries. Discovery should collect candidate devices, fetch or parse enough metadata to identify BRAVIA TVs, deduplicate results, and expose app-friendly device identities.

**Alternatives considered**:

- IP range sweep: rejected because it is slower, noisier on user networks, and harder to make reliable within the 15-second success criterion.
- User-entered IP only: retained as fallback but insufficient for this feature.

## Decision: Keep protocol parsing and discovery service in `SonyRemoteModules`

**Rationale**: Parsing device descriptions, deduplicating discovery results, and exposing discovery outcomes are stable non-UI concerns. Package tests can cover these behaviors without launching the app or requiring SwiftUI.

**Alternatives considered**:

- Put all discovery code in the app target: rejected because it would mix stable protocol behavior with UI flow and make parser tests less isolated.
- Create a new package immediately: rejected because existing `SonyRemoteCore` and `SonyRemoteNetworking` already provide the right core/network split.

## Decision: Keep auto-connect UI state and orchestration in the app target

**Rationale**: The first-launch, scanning, devices-found, connecting, connected, no-devices, and clear-confirmation states are product-flow decisions tied to the Figma screens. The page view model should coordinate discovery, persistence, and remote-page readiness.

**Alternatives considered**:

- Put auto-connect view models inside the package: rejected because these view models are app-specific and coupled to screen navigation and presentation.
- Let child view models communicate directly: rejected by the constitution and architecture guide; page-level coordination remains the rule.

## Decision: Remember one connected TV and preserve manual IP fallback

**Rationale**: The spec and Figma text say the app remembers the connected device and opens directly into the remote later. The existing product still needs manual setup when discovery fails, and the feature scope does not require multi-device switching.

**Alternatives considered**:

- Multi-device management: deferred because it expands settings, persistence, and selection behavior beyond the requested discovery chain.
- Discovery-only without persistence: rejected because returning users would repeat setup and miss the designed behavior.

## Decision: Use automated doubles for tests and manual smoke for real discovery

**Rationale**: Parser, deduplication, cancellation, retry, connection-state, and persistence behavior can be tested with fixtures and test doubles. Real discovery requires local-network conditions and a physical BRAVIA TV, so it must be documented as manual smoke instead of being hidden inside normal unit tests.

**Alternatives considered**:

- Require local network in automated tests: rejected because normal CI and simulator runs should not depend on a real TV.
- Skip real-device validation: rejected because the feature is explicitly about running the discovery chain end to end.
