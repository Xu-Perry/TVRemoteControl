# Open Source SDK Candidates

This document tracks open source Swift packages that may be useful for
SonyRemoteController. It is a dependency decision record, not a list of packages
that must be installed immediately.

Default rule: prefer Apple frameworks for v1 unless a package removes meaningful
complexity without weakening the architecture in `docs/AppArchitecture.md`.

## Current Recommendation

Do not add third-party runtime packages yet.

For the v1 BRAVIA TV MVP, the expected implementation can use:

- `URLSession` for BRAVIA REST JSON-RPC and IRCC-IP HTTP requests.
- `Security` framework for Keychain access.
- `OSLog` for local diagnostics.
- `Network.framework` for automatic BRAVIA discovery and UDP multicast behavior.
- Swift Testing for unit tests.

Add a third-party package only when the first implementation proves the native
API cost is high enough to justify the dependency.

## Candidate Packages

### KeychainAccess

- URL: `https://github.com/kishikawakatsumi/KeychainAccess`
- Product: `KeychainAccess`
- License: MIT
- Current SPI release checked: `v4.2.2`
- Role: simpler Keychain wrapper for saving BRAVIA PSK values.
- Recommendation: evaluate when implementing PSK persistence.

Why it may help:

- Clean Swift API over Keychain item set/get/remove.
- No package dependencies.
- Supports common Keychain accessibility and access group options.

Why not add immediately:

- V1 needs only simple PSK storage, which can be implemented directly with
  `Security`.
- The latest release is old, even though the package remains widely used.

Adoption rule:

- Add only if native Keychain code starts leaking low-level `OSStatus` handling
  into feature or persistence code.
- Wrap it behind a local `SecretStore` protocol so the app does not depend on
  KeychainAccess APIs outside the persistence boundary.

### SnapshotTesting

- URL: `https://github.com/pointfreeco/swift-snapshot-testing`
- Product: `SnapshotTesting`
- License: MIT
- Current SPI release checked: `1.19.2`
- Role: snapshot tests for stable remote-control layouts and settings screens.
- Recommendation: evaluate after the first UI implementation stabilizes.

Why it may help:

- Works with Swift Testing.
- Can snapshot views, view controllers, request data, and encoded values.
- Useful for catching layout regressions in the remote pad and settings form.

Why not add immediately:

- Snapshot baselines add repository artifacts and maintenance cost.
- The v1 UI should first be validated with focused state and UI smoke tests.

Adoption rule:

- Add only to test targets.
- Start with one or two high-value snapshots: disconnected remote page and
  connected remote page at a compact iPhone size.

### swift-log

- URL: `https://github.com/apple/swift-log`
- Product: `Logging`
- License: Apache 2.0
- Current SPI release checked: `1.12.0`
- Role: structured logging API if diagnostics need to be shared across packages.
- Recommendation: defer.

Why it may help:

- Lightweight logging facade.
- No package dependencies.
- Useful if `SonyRemoteNetworking` becomes platform-independent or needs shared
  logging without importing app-specific logging code.

Why not add immediately:

- iOS app diagnostics can start with `OSLog`.
- A small v1 app does not yet need a logging abstraction.

Adoption rule:

- Add only if multiple SPM packages need a common logging API or if tests need a
  mock log handler.

### XMLCoder

- URL: `https://github.com/CoreOffice/XMLCoder`
- Product: `XMLCoder`
- License: MIT
- Current SPI release checked: `0.18.1`
- Role: XML encoding/decoding if IRCC-IP SOAP handling grows beyond a static
  request body.
- Recommendation: defer.

Why it may help:

- Codable-based XML encoder and decoder.
- No package dependencies.
- Useful if the app later needs to parse complex XML responses or UPnP device
  descriptions.

Why not add immediately:

- V1 IRCC-IP can generate a small SOAP envelope directly.
- BRAVIA REST APIs are JSON-RPC, not XML.

Adoption rule:

- Add only if XML parsing becomes more than a small, well-tested local parser.

### Alamofire

- URL: `https://github.com/Alamofire/Alamofire`
- Product: `Alamofire`
- License: MIT
- Current SPI release checked: `5.11.2`
- Role: higher-level HTTP networking.
- Recommendation: do not use for v1.

Why it may help:

- Mature HTTP client with request adaptation, validation, retries, and
  interceptors.
- No package dependencies.

Why not add for this app now:

- The v1 protocol surface is small: a few POST requests with custom headers.
- `URLSession` keeps the networking package simpler and avoids adapting a large
  client around JSON-RPC and SOAP-specific behavior.

Adoption rule:

- Reconsider only if the app expands into many authenticated REST services with
  shared retry, request adaptation, and response validation needs.

### ViewInspector

- URL: `https://github.com/nalexn/ViewInspector`
- Product: `ViewInspector`
- License: MIT
- Current SPI release checked: `0.10.3`
- Role: SwiftUI view introspection tests.
- Recommendation: avoid for v1 unless a specific view test cannot be expressed
  through state/view-model tests or UI tests.

Why it may help:

- Can inspect SwiftUI view hierarchy and trigger control callbacks.
- Useful for targeted unit tests around simple SwiftUI views.

Why to be cautious:

- It relies on SwiftUI runtime structure, so compatibility can lag behind new
  SDK changes.
- The project has reported SDK 26 and Swift 6 issues in open discussions/issues.

Adoption rule:

- Add only to test targets.
- Prefer testing State/ViewModel behavior first.

### CocoaAsyncSocket

- URL: `https://github.com/robbiehanson/CocoaAsyncSocket`
- Product: `CocoaAsyncSocket`
- License: verify before adoption
- Current SPI release checked: `7.6.5`
- Role: low-level socket support for future discovery or custom IP protocols.
- Recommendation: avoid for v1.

Why it may help:

- Mature asynchronous socket library.
- Could support custom UDP/TCP behavior if discovery or Simple IP Control becomes
  complex.

Why not add now:

- Automatic discovery is now in scope, but native `Network.framework` is the
  selected first implementation path for UDP needs.
- License metadata should be verified before adoption.

Adoption rule:

- Consider only after a concrete discovery or socket requirement cannot be met
  cleanly with Apple frameworks.

## Dependency Intake Checklist

Before adding any package:

1. Confirm the feature cannot be implemented cleanly with Apple frameworks.
2. Check license, latest release, maintenance activity, and transitive
   dependencies.
3. Add the package only to the narrowest target that needs it.
4. Wrap runtime dependencies behind local protocols when they touch app
   architecture boundaries.
5. Add at least one test that would fail if the package integration is removed or
   misconfigured.
6. Update this document with the final decision and rationale.

## Recommended Near-Term Actions

1. Start v1 implementation with no third-party runtime dependencies.
2. Implement `SecretStore` using native `Security`; switch to KeychainAccess only
   if native code becomes noisy.
3. Implement BRAVIA networking with `URLSession`.
4. Add SnapshotTesting later only after the remote screen layout stabilizes.
5. Revisit discovery-related packages when automatic discovery becomes an
   explicit v2 scope item.
