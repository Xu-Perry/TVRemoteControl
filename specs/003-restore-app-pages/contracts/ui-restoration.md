# UI Restoration Contract

This contract defines externally visible app behavior for the Figma page restoration. It is written as a UI contract because the feature is a native app flow, not a public network API.

## Design Source

- Figma file: `BRAVIA Controller UI Kit`
- Figma page: `BRAVIA Controller - UI Screens`
- Verified frames:
  - `01 Main Remote`
  - `03 Input Source Sheet`
  - `04 Keyboard Input`
  - `05 More Keys Sheet`
  - `06 Settings`
  - `07 Design Tokens`

## Main Remote Page

**Given** a saved TV is connected, **when** the main remote page appears, **then** it must expose:
- Title `BRAVIA Controller`.
- Top-right settings action.
- Device card with TV thumbnail, device name, and connected status.
- Vertical `音量` control with plus and minus actions.
- Vertical `频道` control with up and down actions.
- Circular directional pad with up, down, left, right, and `OK`.
- Power, home, back, and mute actions.
- Three lower action cards: `输入源`, `键盘输入`, and `更多按键`.

**Must not**:
- Add a bottom tab bar.
- Hide settings behind a secondary menu.
- Disable visual controls while preserving tappable invisible regions.

## Input Source Sheet

**Trigger**: Tap `输入源` from main remote.

**Presentation**: Bottom sheet over the main remote surface.

**Required rows**:
- `电视直播`
- `HDMI 1`
- `HDMI 2`
- `HDMI 3`
- `USB`

**Behavior**:
- The current source is visually selected when known.
- Dismissing the sheet returns to main remote with device context unchanged.
- Source send failure leaves the sheet available and surfaces clear feedback.

## Keyboard Input Bar

**Trigger**: Tap `键盘输入` from main remote.

**Presentation**: Input bar above the iOS system keyboard while the main remote page remains visible.

**Required content**:
- Target TV context with connected device name.
- Text input area.
- Character count.
- `发送到电视`, `清空`, and `删除` actions.
- Dismiss affordance for hiding keyboard input.

**Behavior**:
- Opening keyboard input must not push, cover, or otherwise navigate away from the main remote page.
- Clear empties the draft.
- Delete removes the final character when available.
- Send attempts to send text to the connected TV only when the command path is available.
- Dismissing keyboard input preserves the draft and connected device context.

## More Keys Sheet

**Trigger**: Tap `更多按键` from main remote.

**Presentation**: Bottom sheet over the main remote surface.

**Required content**:
- Numeric keys 1 through 9 and 0.
- `菜单`, `返回`, `信息`, `选项`.
- Close or swipe-dismiss affordance.

**Behavior**:
- Supported keys send their mapped command when connected.
- Unsupported keys are not silently tappable; implementation must either map them or make their disabled state explicit.
- Dismissing the sheet returns to main remote with device context unchanged.

## Settings Page

**Trigger**: Tap the top-right settings action from main remote.

**Presentation**: Page navigation from the main remote page.

**Required content**:
- Back action.
- Title `设置`.
- Connected device card.
- Section `设备` with rows `设备管理`, `自动连接`, and `忘记此设备`.
- Section `遥控器` with rows `按键震动反馈`, `长按连续发送`, and `保持屏幕常亮`.
- Section `关于` with rows `帮助与反馈`, `隐私政策`, and `关于应用`.

**About behavior**:
- `帮助与反馈`, `隐私政策`, and `关于应用` do not navigate in this feature.
- Tapping these rows must keep the settings page visible.
- The app must not show an empty placeholder destination for these rows.

## Accessibility And Layout Contract

- Primary interactive controls maintain at least 44 x 44 point touch targets.
- Labels remain readable and non-overlapping on supported iPhone portrait widths.
- Icon-only controls expose accessibility labels.
- Disabled controls are visibly disabled and announced as disabled where applicable.
- Dynamic Type must not cause primary labels to overlap adjacent controls.
