# Quickstart: BRAVIA Device Auto Discovery

## Build And Automated Checks

Run app unit tests:

```sh
xcodebuild test \
  -scheme SonyRemoteController \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' \
  -only-testing:SonyRemoteControllerTests
```

Run package tests:

```sh
cd Packages/SonyRemoteModules
env CLANG_MODULE_CACHE_PATH=/private/tmp/sonyremote-clang-cache swift test
```

Run an app build:

```sh
xcodebuild build \
  -scheme SonyRemoteController \
  -destination 'generic/platform=iOS Simulator' \
  -quiet
```

Check generated markdown and source whitespace:

```sh
git diff --check
```

## Figma Reference

Use `figma-use status` to confirm the current design file, then inspect these frames in `BRAVIA Controller UI Kit`:

- `02A Auto Connect - First Launch`
- `02B Auto Connect - Scanning`
- `02C Auto Connect - Devices Found`
- `02D Auto Connect - Connecting`
- `02E Auto Connect - Connected`
- `02F Auto Connect - No Devices`
- `02G Auto Connect - Clear Confirmation`

## Manual Smoke Path

Prerequisites:

- iPhone and BRAVIA TV are on the same local network.
- BRAVIA TV is awake.
- TV-side IP Control is enabled.
- TV-side Pre-Shared Key authentication is enabled when required.
- TV-side Remote Device Control is enabled.

Happy path:

1. Install and launch the app with no remembered TV.
2. Confirm the first-launch auto-connect screen is shown.
3. Start scanning nearby devices.
4. Confirm scanning progress is visible and cancellable.
5. Confirm the BRAVIA TV appears in the discovered-device list.
6. Select the TV.
7. Confirm the connecting state names the selected TV.
8. Confirm the connected-ready state appears.
9. Enter the remote.
10. Confirm the remote header shows the selected BRAVIA TV as connected.
11. Relaunch the app and confirm the remembered TV restores without repeating setup.

Recovery path:

1. Break one prerequisite, such as using a different Wi-Fi network or turning off the TV.
2. Start scanning.
3. Confirm the no-devices state appears with retry, manual IP entry, and troubleshooting guidance.
4. Retry scanning after restoring prerequisites.
5. Confirm the TV appears without restarting the app.

Clear path:

1. From a remembered connected TV, choose clear connection.
2. Confirm the destructive action.
3. Confirm the remembered TV is removed and first-launch setup returns.
