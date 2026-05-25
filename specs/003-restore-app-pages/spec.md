# Feature Specification: Figma App Page Restoration

**Feature Branch**: `003-restore-app-pages`  
**Created**: 2026-05-06  
**Status**: Draft  
**Input**: User description: "使用figma-use获取最新设计稿，还原设计稿中的主页面以及其他页面吧，设置页面中的`关于`段落, 由于还没有内容，可以暂时不支持跳转"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Use the restored main remote page (Priority: P1)

As a user with a connected TV TV, I want the main remote page to match the latest design so that the app feels like a complete daily-use remote rather than a setup-only utility.

**Why this priority**: The main remote page is the primary surface users see after setup and carries the core value of the app.

**Independent Test**: Can be tested by opening the app with a connected TV state and comparing the visible main page against the latest Figma frame `01 Main Remote`.

**Acceptance Scenarios**:

1. **Given** a connected TV is available, **When** the user opens the remote experience, **Then** the page shows the app title, settings entry, connected device card, volume control, channel control, directional pad, OK button, power, home, back, mute, input source, keyboard input, and more keys controls in the design-aligned layout.
2. **Given** the main remote page is visible, **When** the user reviews the connected device area, **Then** the device name and connected status are prominent and visually consistent with the latest design.
3. **Given** the main remote page is visible, **When** the user taps a supported remote control, **Then** the control remains recognizable and reachable without the page navigating away unexpectedly.

---

### User Story 2 - Access secondary remote controls from the main page (Priority: P2)

As a user controlling a TV, I want access to input source, keyboard input, and more keys controls shown in the design so that common remote tasks are available without crowding the main page.

**Why this priority**: These pages expand the remote from basic controls into a practical controller while keeping the main page focused.

**Independent Test**: Can be tested by launching each secondary control from the main page and verifying each presentation against the corresponding Figma frames `03 Input Source Sheet`, `04 Keyboard Input`, and `05 More Keys Sheet`.

**Acceptance Scenarios**:

1. **Given** the main remote page is visible, **When** the user opens input source, **Then** a bottom sheet lists `电视直播`, `HDMI 1`, `HDMI 2`, `HDMI 3`, and `USB`, with one current source visibly selected.
2. **Given** the main remote page is visible, **When** the user opens keyboard input, **Then** the main page remains visible, the system keyboard is focused, and a keyboard input bar appears above it with target device context, text entry, character count, send, clear, and delete actions.
3. **Given** the main remote page is visible, **When** the user opens more keys, **Then** a bottom sheet provides numeric keys, menu, back, info, and options controls.
4. **Given** a secondary remote surface or keyboard input bar is open, **When** the user dismisses it, **Then** the user remains on the main remote page without losing the connected device context.

---

### User Story 3 - Manage settings with design-aligned sections (Priority: P3)

As a user, I want the settings page to match the latest design and clearly separate device, remote, and about options so that configuration feels predictable.

**Why this priority**: Settings are important for trust and recovery, but they are secondary to everyday remote control.

**Independent Test**: Can be tested by opening settings from the main remote page and comparing the visible sections and rows against the latest Figma frame `06 Settings`.

**Acceptance Scenarios**:

1. **Given** the main remote page is visible, **When** the user opens settings, **Then** the settings page shows a back action, title `设置`, connected device card, `设备`, `遥控器`, and `关于` sections.
2. **Given** the settings page is visible, **When** the user reviews the `设备` section, **Then** the page shows `设备管理`, `自动连接` with status `已开启`, and `忘记此设备`.
3. **Given** the settings page is visible, **When** the user reviews the `遥控器` section, **Then** the page shows controls for `按键震动反馈`, `长按连续发送`, and `保持屏幕常亮`.
4. **Given** the settings page is visible, **When** the user reviews the `关于` section, **Then** the page shows `帮助与反馈`, `隐私政策`, and `关于应用` rows, but these rows do not navigate because their destination content is not available yet.

### Edge Cases

- If no connected or remembered TV exists, the restored pages must not imply that commands can be sent to a real TV; the existing setup or connection flow remains responsible for reaching a connected state.
- If the available TV name is longer than the Figma sample, the device card must still present the name and status without overlapping key actions.
- If source selection, keyboard sending, or more-key commands cannot be completed, the user must remain on the current page and receive clear feedback rather than being silently returned to the main page.
- If an `关于` row is tapped before destination content exists, the settings page must stay in place and avoid showing an empty or broken destination.
- If a user increases text size, the primary labels and controls must remain readable and tappable.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST present the main remote page using the latest Figma design frame `01 Main Remote` as the visual and content reference.
- **FR-002**: The main remote page MUST include the app title `TV Remote Control`, a settings entry, a connected device card, volume control, channel control, directional navigation, OK, power, home, back, mute, input source, keyboard input, and more keys controls.
- **FR-003**: The main remote page MUST keep settings accessible from the top-right area and MUST NOT introduce a bottom tab bar for this restoration.
- **FR-004**: Users MUST be able to open the input source sheet from the main remote page.
- **FR-005**: The input source sheet MUST present `电视直播`, `HDMI 1`, `HDMI 2`, `HDMI 3`, and `USB`, and MUST visibly indicate the selected input when one is known.
- **FR-006**: Users MUST be able to open keyboard input from the main remote page without navigating away from the main page.
- **FR-007**: The keyboard input bar MUST show the target TV context, text entry area, character count, send-to-TV action, clear action, and delete action above the system keyboard.
- **FR-008**: Users MUST be able to open the more keys sheet from the main remote page.
- **FR-009**: The more keys sheet MUST include numeric keys, menu, back, info, and options controls.
- **FR-010**: Users MUST be able to open settings from the main remote page and return to the main remote page.
- **FR-011**: The settings page MUST show the connected device card and three sections named `设备`, `遥控器`, and `关于`.
- **FR-012**: The `设备` section MUST include `设备管理`, `自动连接`, and `忘记此设备`.
- **FR-013**: The `遥控器` section MUST include `按键震动反馈`, `长按连续发送`, and `保持屏幕常亮`.
- **FR-014**: The `关于` section MUST include `帮助与反馈`, `隐私政策`, and `关于应用`.
- **FR-015**: The `关于` section rows MUST NOT navigate to a destination until real content exists for those destinations.
- **FR-016**: Restored pages MUST preserve the design's light visual direction, including clear surface grouping, subtle borders, blue primary actions, green connected state, dark primary text, secondary gray text, and red danger emphasis where applicable.
- **FR-017**: Restored pages MUST remain usable on compact iPhone portrait widths without label overlap, clipped primary controls, or unreachable actions.
- **FR-018**: Restored pages MUST preserve the existing auto-connect flow as the entry path when no usable TV is available.

### Key Entities *(include if feature involves data)*

- **Connected Device Summary**: Represents the TV currently shown in the main and settings pages, including display name and connection status.
- **Input Source Option**: Represents a selectable TV input such as live TV, HDMI, or USB, including display name and selected state.
- **Keyboard Draft**: Represents text entered by the user before sending it to the TV, including current content and character count.
- **Remote Preference**: Represents user-configurable remote behaviors such as vibration feedback, continuous sending, and keeping the screen awake.
- **About Row**: Represents an informational settings row that is visible but temporarily has no destination.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of latest Figma app frames for main remote, input source, keyboard input, more keys, and settings have a corresponding reachable app page or presentation state.
- **SC-002**: A connected user can reach input source, keyboard input, more keys, and settings from the main remote page in one tap each.
- **SC-003**: Users can dismiss each secondary surface or keyboard input bar without losing the connected device context in 100% of tested connected-state runs.
- **SC-004**: The settings page shows all nine designed settings rows across `设备`, `遥控器`, and `关于`.
- **SC-005**: Tapping any `关于` row results in no empty page, broken page, or unsupported navigation in 100% of tested runs.
- **SC-006**: Primary labels and controls remain readable and non-overlapping on the supported iPhone portrait sizes used for validation.

## Assumptions

- The latest design source is the connected `figma-use` file `TV Remote Control UI Kit`, page `TV Remote Control - UI Screens`.
- The relevant Figma frames are `01 Main Remote`, `03 Input Source Sheet`, `04 Keyboard Input`, `05 More Keys Sheet`, `06 Settings`, and `07 Design Tokens`.
- Existing automatic discovery and connection behavior remains the source for reaching a connected or no-device state.
- The settings `关于` rows are intentionally visible but inactive for this feature because their content pages are not ready.
- The restoration scope covers iPhone portrait layouts represented by the Figma frames; dedicated iPad, landscape, and custom illustration work remain outside this feature.
