# Quickstart: Remote command visual stability

## Build

```sh
xcodebuild build \
  -scheme TVRemoteController \
  -destination 'generic/platform=iOS Simulator' \
  -quiet
```

## Automated Tests

Run the app unit tests:

```sh
xcodebuild test \
  -scheme TVRemoteController \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' \
  -only-testing:TVRemoteControllerTests
```

Run package tests if shared command or networking behavior changes:

```sh
cd Packages/TVRemoteModules
env CLANG_MODULE_CACHE_PATH=/private/tmp/tvremote-clang-cache swift test
```

## Focused Verification For This Feature

Add or update Swift Testing coverage to verify:

- Successful command send leaves `RemotePageState.status`, `ConnectionHeaderState`, and `RemotePadState.isEnabled` stable.
- Command failure sets `RemotePageState.error` and leaves the connected header/control state stable.
- `RemotePadState.isSendingCommand` resets after both success and failure.
- `RemotePadState.lastCommand` changes only after successful sends.

## Manual Real-Device Smoke

Use [docs/ManualSmokeTest.md](../../docs/ManualSmokeTest.md) with these additional checks:

1. Connect to a real TV TV.
2. Repeatedly tap directional remote commands.
3. Repeatedly tap Home, Back, Volume, Mute, and Power commands.
4. Confirm the entire Remote Page does not flash, reset, jump, or remount.
5. Trigger a command failure if practical and confirm the error banner appears without a full-page visual reset.
