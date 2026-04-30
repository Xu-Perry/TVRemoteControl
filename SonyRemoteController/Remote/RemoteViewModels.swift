import Foundation
import SonyRemoteCore
import SonyRemoteNetworking

@MainActor
final class RemotePageViewModel {
    let state: RemotePageState
    let settings: DeviceSettingsViewModel
    let remotePad: RemotePadViewModel

    private let repository: DeviceRepository
    private let braviaClient: BRAVIAControlling

    init(
        state: RemotePageState,
        repository: DeviceRepository,
        braviaClient: BRAVIAControlling
    ) {
        self.state = state
        self.repository = repository
        self.braviaClient = braviaClient
        self.settings = DeviceSettingsViewModel(
            state: state.settings,
            repository: repository,
            braviaClient: braviaClient
        )
        self.remotePad = RemotePadViewModel(
            state: state.remotePad,
            pageState: state,
            repository: repository,
            braviaClient: braviaClient
        )
        loadSavedDevice()
    }

    func openSettings() {
        if let device = state.savedDevice {
            state.settings.tvName = device.name
            state.settings.ipAddress = device.host
            state.settings.psk = ""
            state.settings.canSave = false
            state.settings.error = nil
            state.settings.successMessage = nil
        }
        state.isSettingsPresented = true
    }

    func closeSettings() {
        state.isSettingsPresented = false
        refreshFromRepository()
    }

    func saveSettings() {
        do {
            let device = try settings.save()
            state.savedDevice = device
            updateStatus(.connected)
            state.isSettingsPresented = false
        } catch {
            state.settings.error = RemoteControlError.map(error)
        }
    }

    func reconnect() async {
        guard let device = state.savedDevice else {
            updateStatus(.noDevice)
            return
        }

        do {
            updateStatus(.connecting)
            let psk = try repository.readPSK(for: device)
            try await braviaClient.testConnection(device: device, psk: psk)
            updateStatus(.connected)
        } catch {
            updateStatus(.failed(RemoteControlError.map(error)))
        }
    }

    private func loadSavedDevice() {
        refreshFromRepository()
    }

    private func refreshFromRepository() {
        do {
            guard let device = try repository.loadDevice() else {
                state.savedDevice = nil
                updateStatus(.noDevice)
                return
            }

            state.savedDevice = device
            do {
                _ = try repository.readPSK(for: device)
                updateStatus(.connected)
            } catch {
                updateStatus(.failed(RemoteControlError.map(error)))
            }
        } catch {
            state.savedDevice = nil
            updateStatus(.failed(RemoteControlError.map(error)))
        }
    }

    private func updateStatus(_ status: ConnectionStatus) {
        state.status = status
        state.remotePad.isEnabled = status.allowsRemoteCommands
        if case let .failed(error) = status {
            state.error = error
        } else {
            state.error = nil
        }

        let title = state.savedDevice?.displayName ?? "No TV Connected"
        state.connection.title = title
        state.connection.subtitle = status.displayText
    }
}

@MainActor
final class DeviceSettingsViewModel {
    let state: DeviceSettingsState

    private let repository: DeviceRepository
    private let braviaClient: BRAVIAControlling

    init(
        state: DeviceSettingsState,
        repository: DeviceRepository,
        braviaClient: BRAVIAControlling
    ) {
        self.state = state
        self.repository = repository
        self.braviaClient = braviaClient
    }

    func testConnection() async {
        state.error = nil
        state.successMessage = nil
        state.canSave = false

        do {
            let host = try validatedHost()
            let psk = try validatedPSK()
            state.isTestingConnection = true
            defer { state.isTestingConnection = false }

            let device = SonyDevice(
                name: state.tvName,
                host: host,
                pskKey: "test"
            )
            try await braviaClient.testConnection(device: device, psk: psk)
            state.lastTestedHost = host
            state.canSave = true
            state.successMessage = "Connection succeeded."
        } catch {
            state.error = RemoteControlError.map(error)
        }
    }

    func save() throws -> SonyDevice {
        let host = try validatedHost()
        let psk = try validatedPSK()
        guard state.canSave, state.lastTestedHost == host else {
            throw RemoteControlError.unreachable
        }
        return try repository.saveDevice(name: state.tvName, host: host, psk: psk)
    }

    private func validatedHost() throws -> String {
        let host = state.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SonyDevice.isValidIPv4Address(host) else {
            throw RemoteControlError.invalidIPAddress
        }
        return host
    }

    private func validatedPSK() throws -> String {
        let psk = state.psk.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !psk.isEmpty else {
            throw RemoteControlError.missingPSK
        }
        return psk
    }
}

@MainActor
final class RemotePadViewModel {
    let state: RemotePadState

    private let pageState: RemotePageState
    private let repository: DeviceRepository
    private let braviaClient: BRAVIAControlling

    init(
        state: RemotePadState,
        pageState: RemotePageState,
        repository: DeviceRepository,
        braviaClient: BRAVIAControlling
    ) {
        self.state = state
        self.pageState = pageState
        self.repository = repository
        self.braviaClient = braviaClient
    }

    func send(_ command: RemoteCommand) async {
        guard pageState.canSendCommands, let device = pageState.savedDevice else {
            pageState.error = .missingDevice
            return
        }

        do {
            state.isSendingCommand = true
            defer { state.isSendingCommand = false }

            let psk = try repository.readPSK(for: device)
            try await braviaClient.send(command: command, device: device, psk: psk)
            state.lastCommand = command
            pageState.error = nil
        } catch {
            pageState.error = RemoteControlError.map(error)
        }
    }
}
