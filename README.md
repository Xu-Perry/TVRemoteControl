# TV Remote Control

TV Remote Control is an iOS 18 SwiftUI app for controlling compatible TVs on the local network.

License: PolyForm Noncommercial License 1.0.0. Noncommercial use is permitted;
commercial use is not licensed by this repository.

## Build

Build the app for the iOS Simulator:

```sh
xcodebuild build \
  -scheme TVRemoteController \
  -destination 'generic/platform=iOS Simulator' \
  -quiet
```

Build for a connected iPhone, allowing Xcode to refresh provisioning profiles:

```sh
xcodebuild build \
  -scheme TVRemoteController \
  -destination 'id=<DEVICE_UDID>' \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration
```

## Test

Run the app unit tests on a concrete simulator:

```sh
xcodebuild test \
  -scheme TVRemoteController \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' \
  -only-testing:TVRemoteControllerTests
```

Run the local Swift package tests:

```sh
cd Packages/TVRemoteModules
env CLANG_MODULE_CACHE_PATH=/private/tmp/tvremote-clang-cache swift test
```


## API

The app communicates with compatible TVs over the local network.
