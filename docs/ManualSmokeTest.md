# Manual BRAVIA Smoke Test

Use this checklist when validating the MVP against a real BRAVIA TV.

## Prerequisites

- iPhone and BRAVIA TV are on the same local network.
- BRAVIA TV is awake.
- TV-side IP Control is enabled.
- TV-side Pre-Shared Key authentication is enabled.
- TV-side Remote Device Control is enabled.
- You know the TV IP address and PSK.

## Install And Launch

1. Build and run `SonyRemoteController` on an iPhone or simulator that can reach
   the same local network.
2. Confirm the first screen shows `No TV Connected`.
3. Confirm remote buttons are disabled.
4. Confirm `Connect a BRAVIA TV` is visible.

## Configure TV

1. Tap `Connect a BRAVIA TV`.
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
