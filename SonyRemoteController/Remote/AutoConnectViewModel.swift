import Foundation
import SonyRemoteCore
import SonyRemoteNetworking

@MainActor
final class AutoConnectViewModel {
    let state: AutoConnectState

    private let pageState: RemotePageState
    private let repository: DeviceRepository
    private let braviaClient: BRAVIAControlling
    private let discoveryService: BRAVIADiscoveryServicing
    private var scanTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?

    init(
        state: AutoConnectState,
        pageState: RemotePageState,
        repository: DeviceRepository,
        braviaClient: BRAVIAControlling,
        discoveryService: BRAVIADiscoveryServicing
    ) {
        self.state = state
        self.pageState = pageState
        self.repository = repository
        self.braviaClient = braviaClient
        self.discoveryService = discoveryService
    }

    func showFirstLaunch() {
        cancelScan()
        connectionTask?.cancel()
        state.screen = .firstLaunch
        state.session = DiscoverySessionState()
        state.discoveredDevices = []
        state.selectedDevice = nil
        state.connectionError = nil
        state.isManualEntryPresented = false
    }

    func restoreRememberedDevice(_ device: SonyDevice?) {
        state.rememberedDevice = device
        if let device {
            state.selectedDevice = DiscoveredBRAVIADevice(
                name: device.displayName,
                host: device.host,
                port: device.port,
                connectionReadiness: .paired
            )
            state.screen = .connectedReady
        } else {
            showFirstLaunch()
        }
    }

    func startScan() {
        cancelScan()
        let sessionID = UUID()
        state.screen = .scanning
        state.discoveredDevices = []
        state.selectedDevice = nil
        state.connectionError = nil
        state.session = DiscoverySessionState(
            id: sessionID,
            phase: .scanning,
            startedAt: Date()
        )

        scanTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await event in discoveryService.discover(timeout: 8) {
                    guard !Task.isCancelled, state.session.id == sessionID else { return }
                    switch event {
                    case let .deviceFound(device):
                        upsert(device)
                        if state.screen == .scanning {
                            state.screen = .devicesFound
                        }
                        state.session.phase = .devicesFound
                        state.session.devices = state.discoveredDevices
                    case let .finished(devices):
                        if !devices.isEmpty {
                            state.discoveredDevices = devices
                            state.session.devices = devices
                            state.session.phase = .devicesFound
                            state.screen = .devicesFound
                        } else if state.discoveredDevices.isEmpty {
                            state.session.phase = .noDevices
                            state.screen = .noDevices
                        }
                        state.session.completedAt = Date()
                    }
                }
            } catch is CancellationError {
                state.session.phase = .cancelled
                state.session.completedAt = Date()
            } catch DiscoveryError.cancelled {
                state.session.phase = .cancelled
                state.session.completedAt = Date()
            } catch {
                state.session.phase = .failed
                state.session.completedAt = Date()
                state.connectionError = RemoteControlError.map(error)
                state.screen = state.discoveredDevices.isEmpty ? .noDevices : .devicesFound
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        if state.screen == .scanning {
            state.session.phase = .cancelled
            state.session.completedAt = Date()
            state.screen = .firstLaunch
        }
    }

    func select(_ device: DiscoveredBRAVIADevice) {
        connectionTask?.cancel()
        state.selectedDevice = device
        state.screen = .connecting
        state.connectionError = nil

        connectionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let transientDevice = device.sonyDevice()
                try await braviaClient.testConnection(device: transientDevice, psk: "")
                let savedDevice = try repository.saveDevice(
                    name: device.displayName,
                    host: device.host,
                    port: device.port,
                    psk: ""
                )
                state.rememberedDevice = savedDevice
                pageState.savedDevice = savedDevice
                pageState.status = .connected
                pageState.connection.title = savedDevice.displayName
                pageState.connection.subtitle = ConnectionStatus.connected.displayText
                pageState.remotePad.isEnabled = true
                pageState.error = nil
                state.screen = .connectedReady
            } catch is CancellationError {
                state.screen = .devicesFound
            } catch {
                state.connectionError = RemoteControlError.map(error)
                state.screen = .devicesFound
            }
        }
    }

    func cancelConnection() {
        connectionTask?.cancel()
        connectionTask = nil
        state.screen = state.discoveredDevices.isEmpty ? .firstLaunch : .devicesFound
    }

    func enterRemote() {
        pageState.isAutoConnectPresented = false
    }

    func openManualEntry() {
        state.isManualEntryPresented = true
        pageState.isSettingsPresented = true
    }

    func showClearConfirmation() {
        state.screen = .clearConfirmation
    }

    func cancelClearConnection() {
        state.screen = .connectedReady
    }

    func clearRememberedConnection() {
        do {
            try repository.deleteDevice()
            pageState.savedDevice = nil
            pageState.status = .noDevice
            pageState.connection.title = "No TV Connected"
            pageState.connection.subtitle = ConnectionStatus.noDevice.displayText
            pageState.remotePad.isEnabled = false
            pageState.error = nil
            pageState.isAutoConnectPresented = true
            showFirstLaunch()
        } catch {
            state.connectionError = RemoteControlError.map(error)
            state.screen = .connectedReady
        }
    }

    private func upsert(_ device: DiscoveredBRAVIADevice) {
        if let index = state.discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            state.discoveredDevices[index] = device
        } else {
            state.discoveredDevices.append(device)
        }
        state.discoveredDevices.sort { $0.displayName < $1.displayName }
    }
}
