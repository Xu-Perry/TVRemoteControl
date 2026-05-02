# SonyController

SonyRemoteController is an iOS 18 SwiftUI app for controlling Sony BRAVIA TVs on the local network.

## Build

Build the app for the iOS Simulator:

```sh
xcodebuild build \
  -scheme SonyRemoteController \
  -destination 'generic/platform=iOS Simulator' \
  -quiet
```

Build for a connected iPhone, allowing Xcode to refresh provisioning profiles:

```sh
xcodebuild build \
  -scheme SonyRemoteController \
  -destination 'id=<DEVICE_UDID>' \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration
```

## Test

Run the app unit tests on a concrete simulator:

```sh
xcodebuild test \
  -scheme SonyRemoteController \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' \
  -only-testing:SonyRemoteControllerTests
```

Run the local Swift package tests:

```sh
cd Packages/SonyRemoteModules
env CLANG_MODULE_CACHE_PATH=/private/tmp/sonyremote-clang-cache swift test
```


## API

[Bravia Rest API](https://pro-bravia.sony.net/zhs/remote-display-control/rest-api/)