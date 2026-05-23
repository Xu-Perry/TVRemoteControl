# SonyRemoteController Architecture

This document adapts the architecture pattern for SwiftUI App with Observation and MVVM

## Core Rule

State is the single source of truth for UI.

- `State` stores UI state only.
- `ViewModel` is the only layer allowed to mutate `State`.
- `View` reads `State` and calls `ViewModel` methods.
- `ViewModel` does not return UI data to `View`; it mutates `State`.

In code review, treat direct `State` mutation from a `View` as an architecture
violation unless the value is purely view-local transient SwiftUI state.

## Layer Responsibilities

### State

State describes what the UI should render. It must not contain business logic,
network requests, persistence, discovery, or command dispatch.

Use Observation for app UI state:

```swift
import Observation

@Observable
@MainActor
final class RemotePageState {
    var header = RemoteHeaderState()
    var deviceList = DeviceListState()
    var remotePad = RemotePadState()
}

@Observable
@MainActor
final class RemoteHeaderState {
    var title: String = "TV Remote"
    var connectionText: String = "Disconnected"
}

@Observable
@MainActor
final class DeviceListState {
    var devices: [DiscoveredDevice] = []
    var isScanning = false
    var errorMessage: String?
}

@Observable
@MainActor
final class RemotePadState {
    var isEnabled = false
    var lastCommand: RemoteCommand?
}
```

State tree should match the UI tree as closely as practical:

```text
RemotePageState
  HeaderState
  DeviceListState
  RemotePadState
```

This keeps component state isolated and prevents one component update from
forcing unrelated components to observe broad page-level changes.

### ViewModel

ViewModel owns behavior, side effects, async orchestration, and state mutation.
For a screen with child components, the page-level view model is also the
composition and coordination container for child view models.

```swift
@MainActor
final class RemotePageViewModel {
    let state: RemotePageState

    let header: RemoteHeaderViewModel
    let deviceList: DeviceListViewModel
    let remotePad: RemotePadViewModel

    init(
        state: RemotePageState,
        discoveryService: DeviceDiscoveryService,
        remoteService: RemoteCommandService
    ) {
        self.state = state

        self.header = RemoteHeaderViewModel(state: state.header)
        self.deviceList = DeviceListViewModel(
            state: state.deviceList,
            discoveryService: discoveryService
        )
        self.remotePad = RemotePadViewModel(
            state: state.remotePad,
            remoteService: remoteService
        )
    }
}
```

Child view models own local behavior for their component:

```swift
@MainActor
final class DeviceListViewModel {
    let state: DeviceListState

    private let discoveryService: DeviceDiscoveryService

    init(state: DeviceListState, discoveryService: DeviceDiscoveryService) {
        self.state = state
        self.discoveryService = discoveryService
    }

    func scan() async {
        state.isScanning = true
        defer { state.isScanning = false }

        do {
            state.devices = try await discoveryService.discoverDevices()
            state.errorMessage = nil
        } catch {
            state.errorMessage = "Unable to find compatible TVs."
        }
    }
}
```

### View

View renders state and forwards user intent to the view model.

```swift
struct RemotePageView: View {
    let state: RemotePageState
    let viewModel: RemotePageViewModel

    var body: some View {
        VStack {
            RemoteHeaderView(
                state: state.header,
                viewModel: viewModel.header
            )

            DeviceListView(
                state: state.deviceList,
                viewModel: viewModel.deviceList
            )

            RemotePadView(
                state: state.remotePad,
                viewModel: viewModel.remotePad
            )
        }
    }
}
```

Component views follow the same rule:

```swift
struct DeviceListView: View {
    let state: DeviceListState
    let viewModel: DeviceListViewModel

    var body: some View {
        List(state.devices) { device in
            Text(device.name)
        }
        .overlay {
            if state.isScanning {
                ProgressView()
            }
        }
        .task {
            await viewModel.scan()
        }
    }
}
```

## Composition Root

Create the state tree and page view model at a stable ownership boundary: app
entry, scene root, or feature coordinator. The root owns dependency construction.

```swift
@main
struct SonyRemoteControllerApp: App {
    @State private var state = RemotePageState()
    @State private var viewModel: RemotePageViewModel

    init() {
        let state = RemotePageState()
        _state = State(initialValue: state)
        _viewModel = State(initialValue: RemotePageViewModel(
            state: state,
            discoveryService: SSDPDeviceDiscoveryService(),
            remoteService: SonyRemoteCommandService()
        ))
    }

    var body: some Scene {
        WindowGroup {
            RemotePageView(state: state, viewModel: viewModel)
        }
    }
}
```

For package modules and previews, expose initializers that accept state and
protocol-backed dependencies so features can be tested without real devices or
network access.

## Cross-Component Communication

Child view models must not hold direct references to sibling view models.

Use this direction:

```text
ChildView -> ChildViewModel -> PageViewModel -> OtherChildViewModel -> OtherChildState
```

Examples:

- Device selection in `DeviceListViewModel` should notify `RemotePageViewModel`.
- `RemotePageViewModel` then updates `RemotePadViewModel` and `RemoteHeaderViewModel`.
- `RemotePadViewModel` must not reach into `DeviceListViewModel` directly.

This keeps `PageViewModel` as the only coordinator and prevents hidden dependency
chains between child components.

## Repository And Service Boundaries

View models can call repositories or services, but those dependencies should be
protocol-backed once tests or module boundaries need substitution.

Recommended split:

- Discovery service: local network scanning and SSDP parsing.
- Device repository: saved devices, selected device, pairing metadata.
- Remote command service: TV device API calls and command serialization.
- Settings repository: user preferences and app-level settings.

The domain layer should define stable models such as `SonyDevice`,
`RemoteCommand`, `ConnectionState`, and `DeviceCapability`.

## Rules

1. State stores UI state only.
2. View never mutates shared UI state directly.
3. View calls intent methods on ViewModel.
4. ViewModel mutates State instead of returning display data.
5. PageViewModel owns child ViewModel creation and cross-child coordination.
6. State tree should mirror UI tree where it improves component isolation.
7. Child ViewModels do not depend on sibling Child ViewModels.
8. Network, discovery, persistence, and protocol parsing live behind services or
   repositories, not inside View.

## When To Extract An SPM Module

Keep new code in the app target until a boundary is clear. Extract to a package
when one of these is true:

- The code is domain logic with focused tests and no app target dependency.
- Multiple features need the same service or model.
- The code needs independent testability without loading the app target.
- The feature has a stable public surface and minimal coupling to app navigation.

Do not create packages just to mirror folders. Package boundaries should enforce
dependency direction.
