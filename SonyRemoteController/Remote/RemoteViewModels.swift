import Foundation
import SonyRemoteCore
import SonyRemoteNetworking

@MainActor
final class RemotePageViewModel {
    let state: RemotePageState
    let settings: DeviceSettingsViewModel
    let remotePad: RemotePadViewModel
    let autoConnect: AutoConnectViewModel

    private let repository: DeviceRepository
    private let braviaClient: BRAVIAControlling
    private let pairingClient: BRAVIAPairing
    private let discoveryService: BRAVIADiscoveryServicing

    init(
        state: RemotePageState,
        repository: DeviceRepository,
        braviaClient: BRAVIAControlling,
        pairingClient: BRAVIAPairing,
        discoveryService: BRAVIADiscoveryServicing,
        haptics: RemoteHapticsProviding? = nil
    ) {
        self.state = state
        self.repository = repository
        self.braviaClient = braviaClient
        self.pairingClient = pairingClient
        self.discoveryService = discoveryService
        self.settings = DeviceSettingsViewModel(
            state: state.settings,
            repository: repository,
            braviaClient: braviaClient
        )
        self.remotePad = RemotePadViewModel(
            state: state.remotePad,
            pageState: state,
            repository: repository,
            braviaClient: braviaClient,
            haptics: haptics
        )
        self.autoConnect = AutoConnectViewModel(
            state: state.autoConnect,
            pageState: state,
            repository: repository,
            braviaClient: braviaClient,
            pairingClient: pairingClient,
            discoveryService: discoveryService
        )
        loadSavedDevice()
    }

    func openSettings() {
        state.isKeyboardInputActive = false
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

    func openDeviceManagement() {
        state.isSettingsPresented = false
        state.presentedRemoteSurface = nil
        state.isKeyboardInputActive = false
        autoConnect.restoreRememberedDevice(state.savedDevice)
        state.isAutoConnectPresented = true
    }

    func openSettingsDeviceManagement() {
        state.presentedRemoteSurface = nil
        state.isKeyboardInputActive = false
        autoConnect.restoreRememberedDevice(state.savedDevice)
        state.settings.presentedRoute = .deviceManagement
    }

    func openSettingsRoute(_ route: SettingsRoute) {
        state.settings.presentedRoute = route
    }

    func closeSettingsRoute() {
        state.settings.presentedRoute = nil
    }

    func closeSettings() {
        state.isSettingsPresented = false
        state.settings.presentedRoute = nil
        refreshFromRepository()
    }

    func openInputSourceSheet() {
        guard !state.isAutoConnectPresented else { return }
        state.isKeyboardInputActive = false
        state.presentedRemoteSurface = .inputSourceSheet
    }

    func openKeyboardInput() {
        guard !state.isAutoConnectPresented else { return }
        state.keyboardDraft.errorMessage = nil
        state.keyboardDraft.status = state.keyboardDraft.trimmedText.isEmpty ? .empty : .editing
        state.presentedRemoteSurface = nil
        state.isKeyboardInputActive = true
    }

    func openMoreKeysSheet() {
        guard !state.isAutoConnectPresented else { return }
        state.isKeyboardInputActive = false
        state.presentedRemoteSurface = .moreKeysSheet
    }

    func dismissRemoteSurface() {
        state.presentedRemoteSurface = nil
        state.isKeyboardInputActive = false
    }

    func closeKeyboardInput() {
        state.isKeyboardInputActive = false
    }

    func selectInputSource(_ option: InputSourceOption) async {
        guard let index = state.inputSources.firstIndex(where: { $0.id == option.id }) else {
            return
        }

        for sourceIndex in state.inputSources.indices {
            state.inputSources[sourceIndex].isSelected = sourceIndex == index
        }

        guard let command = option.command else {
            state.error = .remoteControlUnavailable
            return
        }

        await remotePad.send(command)
    }

    func clearKeyboardDraft() {
        state.keyboardDraft.text = ""
        state.keyboardDraft.errorMessage = nil
        state.keyboardDraft.status = .empty
    }

    func deleteLastKeyboardCharacter() {
        guard !state.keyboardDraft.text.isEmpty else { return }
        state.keyboardDraft.text.removeLast()
        state.keyboardDraft.errorMessage = nil
        state.keyboardDraft.status = state.keyboardDraft.trimmedText.isEmpty ? .empty : .editing
    }

    func updateKeyboardDraftText(_ text: String) {
        let limitedText = String(text.prefix(state.keyboardDraft.maxLength))
        state.keyboardDraft.text = limitedText
        state.keyboardDraft.errorMessage = nil
        state.keyboardDraft.status = state.keyboardDraft.trimmedText.isEmpty ? .empty : .editing
    }

    func sendKeyboardDraft() async {
        let text = state.keyboardDraft.trimmedText
        guard !text.isEmpty else {
            state.keyboardDraft.status = .empty
            state.keyboardDraft.errorMessage = "请输入要发送到电视的文字。"
            return
        }

        guard state.canSendCommands, let device = state.savedDevice else {
            state.keyboardDraft.status = .failed
            state.keyboardDraft.errorMessage = RemoteControlError.missingDevice.recoverySuggestion
            return
        }

        do {
            state.keyboardDraft.status = .sending
            state.keyboardDraft.errorMessage = nil
            let credential = try repository.readCredential(for: device)
            try await braviaClient.sendText(text, device: device, credential: credential)
            state.keyboardDraft.status = .sent
            state.keyboardDraft.errorMessage = nil
        } catch {
            state.keyboardDraft.status = .failed
            state.keyboardDraft.errorMessage = RemoteControlError.map(error).recoverySuggestion
        }
    }

    func sendMoreKeyAction(_ action: MoreKeyAction) async {
        guard let command = action.command else {
            state.error = .remoteControlUnavailable
            return
        }
        await remotePad.send(command)
    }

    func setHapticFeedbackEnabled(_ isEnabled: Bool) {
        state.remotePreferences.isHapticFeedbackEnabled = isEnabled
    }

    func saveSettings() {
        do {
            let device = try settings.save()
            state.savedDevice = device
            updateStatus(.connected)
            state.autoConnect.isManualEntryPresented = false
            state.settings.presentedRoute = nil
            state.isSettingsPresented = false
            state.isAutoConnectPresented = false
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
            let credential = try repository.readCredential(for: device)
            try await braviaClient.testConnection(device: device, credential: credential)
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
                state.isAutoConnectPresented = true
                state.presentedRemoteSurface = nil
                state.isKeyboardInputActive = false
                autoConnect.showFirstLaunch()
                return
            }

            state.savedDevice = device
            state.autoConnect.rememberedDevice = device
            do {
                let credential = try repository.readCredential(for: device)
                updateStatus(.connecting)
                state.isAutoConnectPresented = false
                Task {
                    await verifyRestoredDevice(device, credential: credential)
                }
            } catch {
                updateStatus(.failed(RemoteControlError.map(error)))
                state.isAutoConnectPresented = true
                autoConnect.restoreRememberedDevice(device)
            }
        } catch {
            state.savedDevice = nil
            updateStatus(.failed(RemoteControlError.map(error)))
            state.isAutoConnectPresented = true
            autoConnect.showFirstLaunch()
        }
    }

    private func verifyRestoredDevice(_ device: SonyDevice, credential: BRAVIAAuthCredential) async {
        do {
            try await braviaClient.testConnection(device: device, credential: credential)
            guard state.savedDevice == device else { return }
            updateStatus(.connected)
        } catch {
            guard state.savedDevice == device else { return }
            updateStatus(.failed(RemoteControlError.map(error)))
            state.presentedRemoteSurface = nil
            state.isKeyboardInputActive = false
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
                pskKey: "test",
                connectionMode: .psk
            )
            try await braviaClient.testConnection(device: device, credential: .psk(psk))
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
        return try repository.saveDevice(name: state.tvName, host: host, port: 80, psk: psk)
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
    private let haptics: RemoteHapticsProviding

    init(
        state: RemotePadState,
        pageState: RemotePageState,
        repository: DeviceRepository,
        braviaClient: BRAVIAControlling,
        haptics: RemoteHapticsProviding? = nil
    ) {
        self.state = state
        self.pageState = pageState
        self.repository = repository
        self.braviaClient = braviaClient
        self.haptics = haptics ?? NoOpRemoteHaptics()
    }

    func send(_ command: RemoteCommand) async {
        guard pageState.canSendCommands, let device = pageState.savedDevice else {
            pageState.error = .missingDevice
            return
        }

        if pageState.remotePreferences.isHapticFeedbackEnabled {
            haptics.impact()
        }

        do {
            state.isSendingCommand = true
            defer { state.isSendingCommand = false }

            let credential = try repository.readCredential(for: device)
            try await braviaClient.send(command: command, device: device, credential: credential)
            state.lastCommand = command
            pageState.error = nil
        } catch {
            pageState.error = RemoteControlError.map(error)
        }
    }
}
