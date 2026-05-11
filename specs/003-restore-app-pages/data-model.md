# Data Model: Figma App Page Restoration

## RemotePageState

Represents the whole connected remote experience.

**Fields**:
- `connection`: current device header state.
- `settings`: settings page state.
- `remotePad`: primary command sending state.
- `autoConnect`: existing setup and discovery state.
- `savedDevice`: saved TV, when available.
- `status`: current connection status.
- `error`: latest remote-page error.
- `isSettingsPresented`: whether settings is open.
- `isAutoConnectPresented`: whether setup/discovery is open.
- `presentedRemoteSurface`: current secondary sheet surface for input source or more keys.
- `isKeyboardInputActive`: whether the main page keyboard input bar is active and should focus text entry.
- `inputSources`: available input source options.
- `keyboardDraft`: current keyboard input state.
- `remotePreferences`: local remote preference state.

**Validation rules**:
- `presentedRemoteSurface` must be empty and `isKeyboardInputActive` must be false when the auto-connect flow owns the screen.
- Secondary surfaces must preserve `savedDevice` and `status` when dismissed.
- Command-capable surfaces and keyboard send actions must respect `status.allowsRemoteCommands`.

## RemoteSurface

Represents the secondary sheet UI currently presented from the main remote page.

**Values**:
- `inputSourceSheet`: bottom sheet for input source choices.
- `moreKeysSheet`: bottom sheet for numeric and advanced keys.

**State transitions**:
- Main remote -> input source sheet by tapping `输入源`.
- Main remote -> more keys sheet by tapping `更多按键`.
- Any secondary sheet -> main remote by dismissing or completing the sheet.

## KeyboardInputActivation

Represents the inline keyboard input mode on the main remote page.

**State transitions**:
- Main remote -> keyboard input bar by tapping `键盘输入`.
- Keyboard input bar -> main remote by dismissing the keyboard/input bar.
- Activating keyboard input must not change `presentedRemoteSurface`, settings navigation, saved device, or connection status.

## ConnectedDeviceSummary

Represents the TV shown in main and settings pages.

**Fields**:
- `displayName`: preferred TV name, falling back to host if unnamed.
- `connectionText`: localized status text.
- `isConnected`: whether remote controls are enabled.

**Validation rules**:
- Long names must be presentable without hiding settings or row actions.
- No-device state must not show connected styling.

## InputSourceOption

Represents one selectable TV input.

**Fields**:
- `id`: stable option identity.
- `title`: visible label, such as `电视直播`, `HDMI 1`, `HDMI 2`, `HDMI 3`, or `USB`.
- `symbolName`: SF Symbol or local icon reference.
- `isSelected`: whether this input is currently selected.
- `command`: optional command or action needed to request the input.

**Validation rules**:
- At most one input source can be selected.
- The list must include the five Figma options for this feature.

## KeyboardDraft

Represents text being prepared for TV input.

**Fields**:
- `text`: current text.
- `maxLength`: maximum supported character count, planned as 500 to match Figma.
- `targetDeviceName`: visible target context.
- `isSending`: whether send-to-TV is in progress.
- `errorMessage`: latest keyboard-send error if any.

**Validation rules**:
- Character count must match the current text length.
- Clear empties the draft.
- Delete removes one character when text is non-empty.
- Send is disabled or produces clear feedback when no connected TV is available.

## MoreKeyAction

Represents a key in the more keys sheet.

**Fields**:
- `id`: stable key identity.
- `title`: visible label.
- `symbolName`: optional SF Symbol.
- `command`: remote command, when supported.
- `isEnabled`: whether the key can be sent in the current connection state.

**Validation rules**:
- Numeric keys 0 through 9 must be present.
- `菜单`, `返回`, `信息`, and `选项` must be present.
- Unsupported commands must either be mapped before implementation or rendered disabled with explicit follow-up scope.

## RemotePreferences

Represents settings under the `遥控器` section.

**Fields**:
- `isHapticFeedbackEnabled`: state for `按键震动反馈`.
- `isContinuousSendEnabled`: state for `长按连续发送`.
- `isKeepScreenAwakeEnabled`: state for `保持屏幕常亮`.

**Validation rules**:
- Toggle changes must mutate state outside the view body.
- Persisting preferences is allowed but must not require a real TV.

## SettingsSection

Represents settings page groupings.

**Fields**:
- `deviceRows`: `设备管理`, `自动连接`, `忘记此设备`.
- `remoteRows`: `按键震动反馈`, `长按连续发送`, `保持屏幕常亮`.
- `aboutRows`: `帮助与反馈`, `隐私政策`, `关于应用`.

**Validation rules**:
- All nine rows must be visible.
- About rows are visible but inactive for this feature.
- `忘记此设备` keeps danger styling or clear destructive affordance.

## AboutRow

Represents an informational settings row with no current destination.

**Fields**:
- `title`: visible row title.
- `symbolName`: row icon.
- `destinationAvailability`: unavailable for this feature.

**Validation rules**:
- Tapping an unavailable row must not change navigation state.
- No empty placeholder detail page should appear.
