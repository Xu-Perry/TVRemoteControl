# Manual TV Smoke Test

Use this checklist when validating the MVP against a real compatible TV.

## Prerequisites

- iPhone and TV are on the same local network.
- TV is awake.
- TV-side IP Control is enabled.
- TV-side Pre-Shared Key authentication is enabled.
- TV-side Remote Device Control is enabled.
- For manual fallback, you know the TV IP address and PSK.

## Install And Launch

1. Build and run `TVRemoteController` on an iPhone or simulator that can reach
   the same local network.
2. Confirm the first screen shows `连接电视`.
3. Confirm `扫描附近设备` and `手动输入 IP` are visible.

## Automatic Discovery

1. Tap `扫描附近设备`.
2. Confirm the screen shows `正在扫描附近设备`.
3. Confirm the scan can be cancelled.
4. Wait for the TV to appear in the discovered device list.
5. Select the TV.
6. Confirm the screen shows `正在连接电视`.
7. Confirm the screen shows the selected TV is ready.
8. Tap `进入遥控器`.
9. Confirm the remote header shows the selected TV as connected.

## Discovery Recovery

Run these checks by temporarily breaking one prerequisite, such as using a
different Wi-Fi network or turning the TV off:

1. Tap `扫描附近设备`.
2. Confirm the screen shows `未发现设备`.
3. Confirm `重新扫描`, `手动输入 IP`, and troubleshooting guidance are visible.
4. Restore the prerequisite and tap `重新扫描`.
5. Confirm the TV can appear without restarting the app.

## Configure TV

1. Tap `手动输入 IP`.
2. Enter a TV name.
3. Enter the TV IP address.
4. Enter the PSK.
5. Tap `Test Connection`.
6. Confirm the settings screen shows `Connection succeeded.`
7. Tap `Save`.
8. Confirm the app returns to the remote screen.
9. Confirm the header shows `Connected`.
10. Confirm remote buttons are enabled.

## Send Commands

Send each command once and confirm the TV responds:

- Up.
- Down.
- Left.
- Right.
- Confirm.
- Home.
- Back.
- Volume Up.
- Volume Down.
- Mute.
- Power.

Then repeatedly tap several directional and utility commands for at least 10
seconds and confirm:

- The whole Remote Page does not flash, redraw, or visually reset.
- The connection header remains stable and continues to show `Connected`.
- The remote pad and utility controls do not jump, disappear, or change disabled
  styling while commands are in flight.
- Button press feedback remains local to the tapped control.

## Failure Checks

Run these checks only after the happy path works:

1. Enter an invalid IP address and confirm the app shows `Invalid IP Address`.
2. Enter a valid IP with an incorrect PSK and confirm the app shows
   `Authentication Failed`.
3. Turn off or disconnect the TV and confirm the app shows a reachability error.
4. If a command failure can be triggered while the app still considers the TV
   connected, confirm the error banner appears without a full-page visual reset.

## Security Checks

- Confirm PSK is not visible on the remote screen.
- Confirm PSK is not stored in UserDefaults metadata.
- Confirm reopening settings does not display the saved PSK as plain text.
