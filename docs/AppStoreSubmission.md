# App Store Submission Notes

Use this file as the source material for App Store Connect and App Review.

## App Information

- App name: TV Remote Control
- Bundle ID: `com.perry.braviacontroller`
- Version: `1.0.1`
- Build: `1`
- Primary category: Utilities
- Platforms: iPhone
- Minimum OS: iOS 18.0
- Support URL: `https://xu-perry.github.io/SonyController/`
- Privacy Policy URL: `https://xu-perry.github.io/SonyController/privacy.html`
- Support email: `xuanyue.pan@icloud.com`

## Product Page Draft

### Subtitle

Local remote control for TVs

### Promotional Text

Discover and control compatible TVs on your local network with a simple, focused remote. Not all TVs are supported.

### Description

TV Remote Control turns your iPhone into a local-network remote for compatible TVs.

Key features:

- Discover compatible TVs on the same Wi-Fi network.
- Works only with TVs that expose supported local-network IP Control or remote-device-control capabilities.
- Pair with the TV using the TV-side pairing code flow.
- Send common remote commands including direction, OK, Home, Back, volume, channel, mute, and power.
- Enter text from the iOS keyboard for supported TV input fields.
- Keep saved TV connection settings on device using Keychain-backed storage.
- Use manual IP entry and connection diagnostics when automatic discovery is unavailable.

The app works on your local network and does not require an account, cloud service, analytics SDK, or advertising SDK.

### Keywords

tv,remote,controller,television,wifi,local network

### What's New

Initial App Store release.

## App Privacy Answers

Recommended App Store Connect answer:

- Data collection: No, this app does not collect data from this app.
- Tracking: No.
- Third-party advertising: No.
- Analytics SDKs: None.
- Crash or diagnostics collection by the developer: None.

Rationale:

- TV name, IP address, and pairing credentials are stored locally for reconnecting to the user's TV.
- Saved connection settings are not sent to the developer or a third-party server.
- The app does not include a third-party SDK, account system, analytics service, advertising SDK, or cloud backend.
- Optional feedback is handled through the user's Mail app via `mailto:` and is user-initiated.

If future versions add analytics, cloud sync, remote support, or in-app feedback upload, update App Store Connect privacy answers and `docs/privacy.html` before submission.

## Export Compliance

The app does not implement proprietary encryption, non-standard encryption, or a custom cryptographic protocol.

Current encryption-related behavior:

- TV control and discovery traffic uses local-network HTTP and UDP multicast.
- Saved credentials use the iOS Keychain through Apple's `Security` framework.
- The privacy policy link opens an HTTPS URL through system URL handling.
- The app does not include CryptoKit, CommonCrypto, OpenSSL, libsodium, or a third-party encryption SDK.

Recommended App Store Connect answer:

- Uses encryption: No, or only exempt encryption.
- Export compliance documentation: Not required.

The app target sets `ITSAppUsesNonExemptEncryption` to `false` in `SonyRemoteController/Info.plist`, so App Store Connect should not require the export compliance questionnaire for each upload.

## Privacy Manifest

The app target includes `SonyRemoteController/PrivacyInfo.xcprivacy`.

- `NSPrivacyTracking`: `false`
- `NSPrivacyCollectedDataTypes`: empty
- Required reason API: `NSPrivacyAccessedAPICategoryUserDefaults`
- Reason: `CA92.1`, because the legacy migration path reads and deletes app-owned `UserDefaults` values only.

## Multicast Networking Entitlement

The app uses SSDP discovery for compatible TVs, which requires local-network multicast/broadcast capability on physical iOS devices.

Current project entitlement:

- `com.apple.developer.networking.multicast`: `true`

Before App Store upload, confirm in the Apple Developer account that the App ID for `com.perry.braviacontroller` has the Multicast Networking restricted entitlement approved and enabled. Then regenerate the App Store provisioning profile and archive with that profile.

Suggested App Review note:

> TV Remote Control uses local network multicast only to discover compatible TVs on the user's Wi-Fi network using SSDP. The app does not operate a cloud service, does not collect analytics, and does not transmit the discovered TV information to the developer. If automatic discovery is unavailable, users can manually enter the TV IP address.

## Reviewer Test Notes

Prerequisites for full functionality:

- iPhone and compatible TV are on the same local network.
- Local Network permission is allowed.
- TV is powered on.
- TV-side IP Control and Remote Device Control are enabled.
- TV-side pairing/authentication is configured.

Suggested review flow:

1. Launch the app.
2. Allow Local Network permission if prompted.
3. Tap `扫描附近设备` to discover a compatible TV on the same network.
4. Select the TV and enter the TV-displayed pairing code if prompted.
5. Use the remote page to send direction, OK, Home, Back, volume, mute, and power commands.
6. If discovery is unavailable in the review environment, use `手动输入 IP` with a reachable TV IP address.

## Pre-Submission Checklist

- [ ] Confirm `https://xu-perry.github.io/SonyController/privacy.html` is publicly reachable.
- [ ] Confirm the App ID has the approved Multicast Networking entitlement.
- [ ] Regenerate and install the App Store distribution provisioning profile after entitlement approval.
- [ ] Archive a Release build for `generic/platform=iOS`.
- [ ] Validate and upload the archive to App Store Connect.
- [ ] Fill App Store Connect App Privacy with the answers above.
- [ ] Confirm App Store Connect accepts the export compliance answer without additional documentation.
- [ ] Upload screenshots for required iPhone sizes.
- [ ] Run `docs/ManualSmokeTest.md` on a real compatible TV and record the result.
