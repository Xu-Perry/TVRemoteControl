import Foundation
import TVRemoteCore
import TVRemoteNetworking

@MainActor
final class RemotePageViewModel {
    let state: RemotePageState
    let settings: DeviceSettingsViewModel
    let connectionDiagnostics: ConnectionDiagnosticsViewModel
    let remotePad: RemotePadViewModel
    let autoConnect: AutoConnectViewModel

    private let repository: DeviceRepository
    private let tvRemoteClient: TVRemoteControlling
    private let pairingClient: TVPairing
    private let discoveryService: TVDiscoveryServicing
    private var deviceNameRefreshTask: Task<Void, Never>?

    init(
        state: RemotePageState,
        repository: DeviceRepository,
        tvRemoteClient: TVRemoteControlling,
        pairingClient: TVPairing,
        discoveryService: TVDiscoveryServicing,
        haptics: RemoteHapticsProviding? = nil
    ) {
        self.state = state
        self.repository = repository
        self.tvRemoteClient = tvRemoteClient
        self.pairingClient = pairingClient
        self.discoveryService = discoveryService
        self.settings = DeviceSettingsViewModel(
            state: state.settings,
            repository: repository,
            tvRemoteClient: tvRemoteClient
        )
        self.connectionDiagnostics = ConnectionDiagnosticsViewModel(
            state: state.connectionDiagnostics,
            pageState: state,
            repository: repository,
            tvRemoteClient: tvRemoteClient,
            discoveryService: discoveryService
        )
        self.remotePad = RemotePadViewModel(
            state: state.remotePad,
            pageState: state,
            repository: repository,
            tvRemoteClient: tvRemoteClient,
            haptics: haptics
        )
        self.autoConnect = AutoConnectViewModel(
            state: state.autoConnect,
            pageState: state,
            repository: repository,
            tvRemoteClient: tvRemoteClient,
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

    func refreshDeviceNameOnHomeAppear() {
        deviceNameRefreshTask?.cancel()

        guard !state.isAutoConnectPresented, let device = state.savedDevice else {
            return
        }

        deviceNameRefreshTask = Task {
            await refreshDeviceName(for: device)
        }
    }

    /// Re-reads the saved device from the keychain and re-runs the connection
    /// verification. If no device is persisted, the app pushes the auto-connect
    /// flow so the user can add or rediscover a TV.
    func retryFromError() {
        refreshFromRepository()
    }

    func refreshDeviceNameIfNeeded() async {
        guard !state.isAutoConnectPresented, let device = state.savedDevice else {
            return
        }

        await refreshDeviceName(for: device)
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

    func submitKeyboardDraft() {
        guard state.keyboardDraft.status != .sending else { return }
        Task { await performSendKeyboardDraft() }
    }

    func sendKeyboardDraft() async {
        guard state.keyboardDraft.status != .sending else { return }
        await performSendKeyboardDraft()
    }

    private func performSendKeyboardDraft() async {
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
            try await tvRemoteClient.sendText(text, device: device, credential: credential)
            closeKeyboardInput()
            clearKeyboardDraft()
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
            try await tvRemoteClient.testConnection(device: device, credential: credential)
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
                _ = try repository.readCredential(for: device)
                state.isAutoConnectPresented = false
                updateStatus(.connected)
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

    private func refreshDeviceName(for device: TVDevice) async {
        do {
            let credential = try repository.readCredential(for: device)
            guard let normalizedName = normalizedFetchedDeviceName(
                try await tvRemoteClient.fetchDeviceName(device: device, credential: credential)
            ) else {
                return
            }

            guard !Task.isCancelled,
                  normalizedName != device.displayName,
                  state.savedDevice == device else {
                return
            }

            let updatedDevice = try repository.updateDeviceName(normalizedName, for: device)
            guard !Task.isCancelled, state.savedDevice == device else { return }
            state.savedDevice = updatedDevice
            state.autoConnect.rememberedDevice = updatedDevice
            updateStatus(state.status)
        } catch {
            return
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
    private let tvRemoteClient: TVRemoteControlling

    init(
        state: DeviceSettingsState,
        repository: DeviceRepository,
        tvRemoteClient: TVRemoteControlling
    ) {
        self.state = state
        self.repository = repository
        self.tvRemoteClient = tvRemoteClient
    }

    func testConnection() async {
        state.error = nil
        state.successMessage = nil
        state.canSave = false

        do {
            let host = try validatedHost()
            let psk = state.psk.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !psk.isEmpty else {
                state.error = .missingPSK
                return
            }

            state.isTestingConnection = true
            defer { state.isTestingConnection = false }

            let testDevice = TVDevice(
                name: state.tvName,
                host: host,
                pskKey: "test",
                connectionMode: .psk
            )
            let credential = TVAuthCredential.psk(psk)
            try await tvRemoteClient.testConnection(device: testDevice, credential: credential)
            // Some TV models accept `getRemoteControllerInfo` without a valid
            // PSK, so the JSON-RPC test alone is not enough to prove that the
            // PSK actually works for sending commands. Probe the IRCC endpoint
            // to make sure the PSK is accepted before letting the user save.
            try await tvRemoteClient.testCommandAccess(device: testDevice, credential: credential)
            state.lastTestedHost = host
            state.canSave = true
            state.successMessage = "连接成功，PSK 认证通过。"
            await fetchAndStoreDeviceName(host: host, credential: credential)
        } catch let error as RemoteControlError {
            state.error = error
        } catch {
            state.error = RemoteControlError.map(error)
        }
    }

    func save() throws -> TVDevice {
        let host = try validatedHost()
        let psk = state.psk.trimmingCharacters(in: .whitespacesAndNewlines)
        guard state.canSave, state.lastTestedHost == host else {
            throw RemoteControlError.unreachable
        }
        return try repository.saveDevice(name: state.tvName, host: host, port: 80, psk: psk)
    }

    private func validatedHost() throws -> String {
        let host = state.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard TVDevice.isValidIPv4Address(host) else {
            throw RemoteControlError.invalidIPAddress
        }
        return host
    }

    private func fetchAndStoreDeviceName(host: String, credential: TVAuthCredential) async {
        let testDevice = TVDevice(name: "", host: host, pskKey: "fetch", connectionMode: .psk)
        guard let name = normalizedFetchedDeviceName(try? await tvRemoteClient.fetchDeviceName(device: testDevice, credential: credential)) else {
            return
        }
        state.tvName = name
    }
}

private func normalizedFetchedDeviceName(_ value: String?) -> String? {
    let name = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !name.isEmpty else {
        return nil
    }

    let genericNames = ["TV", "TELEVISION"]
    guard !genericNames.contains(name.uppercased()) else {
        return nil
    }
    return name
}

@MainActor
final class RemotePadViewModel {
    let state: RemotePadState

    private let pageState: RemotePageState
    private let repository: DeviceRepository
    private let tvRemoteClient: TVRemoteControlling
    private let haptics: RemoteHapticsProviding

    init(
        state: RemotePadState,
        pageState: RemotePageState,
        repository: DeviceRepository,
        tvRemoteClient: TVRemoteControlling,
        haptics: RemoteHapticsProviding? = nil
    ) {
        self.state = state
        self.pageState = pageState
        self.repository = repository
        self.tvRemoteClient = tvRemoteClient
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
            try await tvRemoteClient.send(command: command, device: device, credential: credential)
            state.lastCommand = command
            pageState.error = nil
        } catch {
            pageState.error = RemoteControlError.map(error)
        }
    }
}
