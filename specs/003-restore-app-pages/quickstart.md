# Quickstart: Figma App Page Restoration

## Preconditions

1. Confirm the active feature:

```sh
cat .specify/feature.json
```

Expected feature directory: `specs/003-restore-app-pages`.

2. Confirm Figma is reachable:

```sh
figma-use status
figma-use query "//FRAME"
```

Expected file: `TV Remote Control UI Kit`. Required frames include `01 Main Remote`, `03 Input Source Sheet`, `04 Keyboard Input`, `05 More Keys Sheet`, `06 Settings`, and `07 Design Tokens`.

## Implementation Checklist

1. Keep work in `TVRemoteController/Remote/` unless shared command mappings require package changes.
2. Extend `RemotePageState` with explicit presentation state for input source and more keys, plus keyboard input activation state.
3. Extend view models with intent methods for opening and dismissing each secondary surface and keyboard input.
4. Restore `RemotePageView` to match `01 Main Remote`.
5. Add bottom sheet presentation for `03 Input Source Sheet`.
6. Add a keyboard input bar above the system keyboard for `04 Keyboard Input` without navigating away from main remote.
7. Add bottom sheet presentation for `05 More Keys Sheet`.
8. Restore `DeviceSettingsView` to match `06 Settings`.
9. Keep `帮助与反馈`, `隐私政策`, and `关于应用` visible but non-navigating.
10. Preserve the existing auto-connect flow as the no-device entry path.

## Automated Validation

Run focused app tests:

```sh
xcodebuild test \
  -scheme TVRemoteController \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' \
  -only-testing:TVRemoteControllerTests
```

Run package tests only if package command mappings change:

```sh
cd Packages/TVRemoteModules
env CLANG_MODULE_CACHE_PATH=/private/tmp/tvremote-clang-cache swift test
```

Recommended test cases:
- Connected state opens the restored main remote instead of setup.
- `输入源`, `键盘输入`, `更多按键`, and settings are reachable from main remote in one action.
- Dismissing each secondary surface or keyboard input bar preserves connected device state.
- Keyboard clear and delete mutate `KeyboardDraft` correctly.
- About rows remain visible and do not change navigation state.
- Preference toggles mutate state through the view model.
- Unsupported more-key commands are not silently tappable.

## Manual Figma Validation

Compare the simulator-rendered app against the Figma frames:
- `01 Main Remote`
- `03 Input Source Sheet`
- `04 Keyboard Input`
- `05 More Keys Sheet`
- `06 Settings`

Check:
- No bottom tab bar appears.
- Settings stays in the top-right entry point from main remote.
- Input source and more keys use bottom sheet presentation.
- Keyboard input keeps the main remote page visible and uses an input bar above the system keyboard.
- The settings `关于` rows do not navigate.
- Text does not overlap at compact iPhone widths.

## Final Checks

```sh
git diff --check
git status --short
```
