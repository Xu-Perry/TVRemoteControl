import Foundation
import Testing
import TVRemoteCore
import TVRemoteNetworking
@testable import TVRemoteController

@MainActor
struct TVRemoteControllerTests {
    @Test func startsInNoDeviceState() {
        let harness = Harness()

        #expect(harness.state.status == .noDevice)
        #expect(harness.state.connection.title == "No TV Connected")
        #expect(!harness.state.remotePad.isEnabled)
    }

    @Test func testConnectionEnablesSave() async {
        let harness = Harness()
        harness.state.settings.ipAddress = "192.168.1.2"
        harness.state.settings.psk = "1234"

        await harness.viewModel.settings.testConnection()

        #expect(harness.state.settings.canSave)
        #expect(harness.state.settings.successMessage != nil)
        #expect(harness.state.settings.error == nil)
    }

    @Test func invalidIPAddressShowsLayeredError() async {
        let harness = Harness()
        harness.state.settings.ipAddress = "invalid"
        harness.state.settings.psk = "1234"

        await harness.viewModel.settings.testConnection()

        #expect(harness.state.settings.error == .invalidIPAddress)
        #expect(!harness.state.settings.canSave)
    }

    @Test func testConnectionWithoutPSKShowsMissingPSKError() async {
        let harness = Harness()
        harness.state.settings.ipAddress = "192.168.1.2"

        await harness.viewModel.settings.testConnection()

        #expect(harness.state.settings.error == .missingPSK)
        #expect(!harness.state.settings.canSave)
    }

    @Test func saveAfterSuccessfulTestConnectsRemote() async {
        let harness = Harness()
        harness.state.settings.tvName = "Living Room"
        harness.state.settings.ipAddress = "192.168.1.2"
        harness.state.settings.psk = "1234"

        await harness.viewModel.settings.testConnection()
        harness.viewModel.saveSettings()

        #expect(harness.state.status == .connected)
        #expect(harness.state.remotePad.isEnabled)
        #expect(harness.state.savedDevice?.displayName == "Living Room")
    }

    @Test func unauthorizedTestConnectionSurfacesAuthError() async {
        let harness = Harness(client: MockTVRemoteClient(connectionError: .unauthorized))
        harness.state.settings.ipAddress = "192.168.1.2"
        harness.state.settings.psk = "wrong"

        await harness.viewModel.settings.testConnection()

        #expect(harness.state.settings.error == .unauthorized)
        #expect(!harness.state.settings.canSave)
    }

    @Test func testConnectionRejectsInvalidPSKDetectedByIRCCProbe() async {
        // Some TV models accept getRemoteControllerInfo without a valid
        // PSK, so we must additionally probe the IRCC endpoint to catch a
        // wrong PSK before allowing save.
        let harness = Harness(client: MockTVRemoteClient(commandAccessError: .unauthorized))
        harness.state.settings.ipAddress = "192.168.1.2"
        harness.state.settings.psk = "wrong"

        await harness.viewModel.settings.testConnection()

        #expect(harness.state.settings.error == .unauthorized)
        #expect(!harness.state.settings.canSave)
    }

    @Test func commandFailureShowsErrorBannerState() async {
        let harness = Harness(client: MockTVRemoteClient(sendError: .timeout))
        await harness.connectSavedDevice()

        await harness.viewModel.remotePad.send(.home)

        #expect(harness.state.error == .timeout)
        #expect(harness.state.status == .failed(.timeout))
        #expect(!harness.state.remotePad.isEnabled)
        #expect(harness.state.remotePad.lastCommand == nil)
    }

    @Test func successfulCommandSendKeepsRemotePageStable() async {
        let harness = Harness()
        await harness.connectSavedDevice()
        let stableState = RemotePageSnapshot(state: harness.state)

        await harness.viewModel.remotePad.send(.home)

        #expect(harness.client.sentCommands == [.home])
        #expect(harness.state.remotePad.lastCommand == .home)
        #expect(!harness.state.remotePad.isSendingCommand)
        assertRemotePageStable(stableState, state: harness.state)
    }

    @Test func repeatedSuccessfulCommandSendsKeepRemotePageStable() async {
        let harness = Harness()
        await harness.connectSavedDevice()
        let stableState = RemotePageSnapshot(state: harness.state)

        await harness.viewModel.remotePad.send(.up)
        await harness.viewModel.remotePad.send(.down)

        #expect(harness.client.sentCommands == [.up, .down])
        #expect(harness.state.remotePad.lastCommand == .down)
        #expect(!harness.state.remotePad.isSendingCommand)
        assertRemotePageStable(stableState, state: harness.state)
    }

    @Test func failedCommandSendMarksRemoteUnavailableWhenConnectionFails() async {
        let harness = Harness(client: MockTVRemoteClient(sendError: .timeout))
        await harness.connectSavedDevice()

        await harness.viewModel.remotePad.send(.home)

        #expect(harness.client.sentCommands == [.home])
        #expect(harness.state.error == .timeout)
        #expect(harness.state.status == .failed(.timeout))
        #expect(!harness.state.remotePad.isEnabled)
        #expect(!harness.state.remotePad.isSendingCommand)
    }

    @Test func failedCommandSendDoesNotReplaceLastSuccessfulCommand() async {
        let harness = Harness(client: MockTVRemoteClient(sendError: .timeout))
        await harness.connectSavedDevice()
        harness.state.remotePad.lastCommand = .up

        await harness.viewModel.remotePad.send(.home)

        #expect(harness.state.remotePad.lastCommand == .up)
        #expect(harness.state.error == .timeout)
        #expect(harness.state.status == .failed(.timeout))
    }

    @Test func disabledRemoteDoesNotDispatchCommand() async {
        let harness = Harness()

        await harness.viewModel.remotePad.send(.home)

        #expect(harness.client.sentCommands.isEmpty)
        #expect(harness.state.error == .missingDevice)
        #expect(!harness.state.remotePad.isEnabled)
        #expect(!harness.state.remotePad.isSendingCommand)
    }

    @Test func localRepositoryRestoresDeviceAndPSKAcrossInstances() throws {
        let metadataSecretStore = MockSecretStore()
        let secretStore = MockSecretStore()
        let metadataStore = KeychainDeviceMetadataStore(secretStore: metadataSecretStore, legacyStore: nil)
        let repository = LocalDeviceRepository(metadataStore: metadataStore, secretStore: secretStore)

        let savedDevice = try repository.saveDevice(
            name: " Living Room ",
            host: " 192.168.1.2 ",
            psk: "1234"
        )

        let restoredRepository = LocalDeviceRepository(
            metadataStore: KeychainDeviceMetadataStore(secretStore: metadataSecretStore, legacyStore: nil),
            secretStore: secretStore
        )
        let restoredDevice = try #require(try restoredRepository.loadDevice())
        let encodedMetadata = try #require(try metadataSecretStore.read(for: "saved.tv.device"))
        let rawMetadata = try #require(Data(base64Encoded: encodedMetadata))
        let rawMetadataText = String(decoding: rawMetadata, as: UTF8.self)

        #expect(restoredDevice == savedDevice)
        #expect(restoredDevice.name == "Living Room")
        #expect(restoredDevice.host == "192.168.1.2")
        #expect(try restoredRepository.readPSK(for: restoredDevice) == "1234")
        #expect(rawMetadataText.contains(restoredDevice.pskKey))
        #expect(!rawMetadataText.contains("1234"))
    }

    @Test func localRepositoryPreservesExistingCredentialWhenMetadataSaveFails() throws {
        let existingDevice = TVDevice(name: "Living Room", host: "192.168.1.2", pskKey: "old-key")
        let metadataStore = FailingSaveDeviceMetadataStore(existingDevice: existingDevice)
        let secretStore = MockSecretStore()
        try secretStore.save("old-psk", for: existingDevice.pskKey)
        let repository = LocalDeviceRepository(metadataStore: metadataStore, secretStore: secretStore)

        #expect(throws: RemoteControlError.keychainFailure("Unable to save the TV TV settings.")) {
            try repository.saveDevice(name: "Bedroom", host: "192.168.1.3", psk: "new-psk")
        }
        #expect(try secretStore.read(for: existingDevice.pskKey) == "old-psk")
        #expect(secretStore.values.count == 1)
    }

    @Test func keychainMetadataStoreMigratesLegacyUserDefaultsDevice() throws {
        let suiteName = "TVRemoteControllerTests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let legacyStore = UserDefaultsDeviceMetadataStore(userDefaults: userDefaults, key: "savedDevice")
        let metadataSecretStore = MockSecretStore()
        let savedDevice = TVDevice(name: "Living Room", host: "192.168.1.2", pskKey: "key")
        try legacyStore.saveDevice(savedDevice)

        let metadataStore = KeychainDeviceMetadataStore(
            secretStore: metadataSecretStore,
            key: "saved.tv.device",
            legacyStore: legacyStore
        )

        let restoredDevice = try #require(try metadataStore.loadDevice())

        #expect(restoredDevice == savedDevice)
        #expect(try metadataSecretStore.read(for: "saved.tv.device") != nil)
        #expect(userDefaults.data(forKey: "savedDevice") == nil)
    }

    @Test func saveManualEntryClosesManualRouteAndConnectsRemote() async {
        let harness = Harness()
        harness.viewModel.autoConnect.openManualEntry()
        harness.state.settings.tvName = "Bedroom TV"
        harness.state.settings.ipAddress = "192.168.1.3"
        harness.state.settings.psk = "1234"

        await harness.viewModel.settings.testConnection()
        harness.viewModel.saveSettings()

        #expect(!harness.state.autoConnect.isManualEntryPresented)
        #expect(!harness.state.isSettingsPresented)
        #expect(!harness.state.isAutoConnectPresented)
        #expect(harness.state.status == .connected)
        #expect(harness.state.savedDevice?.displayName == "Bedroom TV")
    }

    @Test func restoresPersistedDeviceAfterConnectionVerification() async throws {
        let state = RemotePageState()
        let repository = MockDeviceRepository()
        repository.stubDevice(psk: "1234")

        _ = RemotePageViewModel(
            state: state,
            repository: repository,
            tvRemoteClient: MockTVRemoteClient(connectionDelayNanoseconds: 50_000_000),
            pairingClient: MockTVRemoteClient(),
            discoveryService: EmptyDiscoveryService()
        )

        #expect(state.savedDevice?.displayName == "Living Room")
        #expect(state.status == .connecting)
        #expect(!state.remotePad.isEnabled)
        #expect(state.connection.title == "Living Room")
        #expect(!state.isAutoConnectPresented)
        try await waitUntil { state.status == .connected }
        #expect(state.status == .connected)
        #expect(state.remotePad.isEnabled)
    }

    @Test func restoredPersistedDeviceFailsVerificationWhenTVIsUnreachable() async throws {
        let state = RemotePageState()
        let repository = MockDeviceRepository()
        repository.stubDevice(psk: "1234")
        let client = MockTVRemoteClient(connectionError: .unreachable)

        _ = RemotePageViewModel(
            state: state,
            repository: repository,
            tvRemoteClient: client,
            pairingClient: MockTVRemoteClient(),
            discoveryService: EmptyDiscoveryService()
        )

        #expect(state.savedDevice?.displayName == "Living Room")
        #expect(state.status == .connecting)
        #expect(!state.remotePad.isEnabled)
        #expect(!state.isAutoConnectPresented)
        #expect(state.connection.title == "Living Room")
        try await waitUntil { state.status == .failed(.unreachable) }

        #expect(state.error == .unreachable)
        #expect(!state.remotePad.isEnabled)
        #expect(state.connection.subtitle == ConnectionStatus.failed(.unreachable).displayText)
    }

    @Test func remoteCommandConnectionFailureMarksRemoteAsFailed() async throws {
        let harness = Harness(client: MockTVRemoteClient(sendError: .unreachable))
        await harness.connectSavedDevice()

        await harness.viewModel.remotePad.send(.power)

        #expect(harness.client.sentCommands == [.power])
        #expect(harness.state.status == .failed(.unreachable))
        #expect(harness.state.error == .unreachable)
        #expect(!harness.state.remotePad.isEnabled)
    }

    @Test func homeAppearRefreshesSavedDeviceNameFromTV() async throws {
        let state = RemotePageState()
        let repository = MockDeviceRepository()
        let savedDevice = TVDevice(name: "192.168.1.2", host: "192.168.1.2", pskKey: "key")
        repository.stubDevice(savedDevice, psk: "1234")
        let client = MockTVRemoteClient(fetchedDeviceName: "Living Room TV")
        let viewModel = RemotePageViewModel(
            state: state,
            repository: repository,
            tvRemoteClient: client,
            pairingClient: client,
            discoveryService: EmptyDiscoveryService()
        )

        state.isAutoConnectPresented = false
        await viewModel.refreshDeviceNameIfNeeded()

        #expect(state.savedDevice?.displayName == "Living Room TV")
        let persistedDevice = try #require(try repository.loadDevice())
        #expect(persistedDevice.displayName == "Living Room TV")
        #expect(persistedDevice.pskKey == savedDevice.pskKey)
        #expect(state.connection.title == "Living Room TV")
    }

    @Test func homeAppearDoesNotReplaceDeviceNameWithGenericTVName() async throws {
        let state = RemotePageState()
        let repository = MockDeviceRepository()
        let savedDevice = TVDevice(name: "Living Room TV", host: "192.168.1.2", pskKey: "key")
        repository.stubDevice(savedDevice, psk: "1234")
        let client = MockTVRemoteClient(fetchedDeviceName: "TV")
        let viewModel = RemotePageViewModel(
            state: state,
            repository: repository,
            tvRemoteClient: client,
            pairingClient: client,
            discoveryService: EmptyDiscoveryService()
        )

        state.isAutoConnectPresented = false
        await viewModel.refreshDeviceNameIfNeeded()

        #expect(state.savedDevice?.displayName == "Living Room TV")
        let persistedDevice = try #require(try repository.loadDevice())
        #expect(persistedDevice.displayName == "Living Room TV")
        #expect(state.connection.title == "Living Room TV")
    }

    @Test func manualConnectionDoesNotSaveGenericFetchedTVName() async {
        let harness = Harness(client: MockTVRemoteClient(fetchedDeviceName: "TV"))
        harness.state.settings.ipAddress = "192.168.1.2"
        harness.state.settings.psk = "1234"

        await harness.viewModel.settings.testConnection()
        harness.viewModel.saveSettings()

        #expect(harness.state.savedDevice?.displayName == "192.168.1.2")
    }

    @Test func missingPersistedPSKRetainsDeviceAndShowsRecoveryError() {
        let state = RemotePageState()
        let repository = MockDeviceRepository()
        repository.stubDevice(psk: nil)

        let viewModel = RemotePageViewModel(
            state: state,
            repository: repository,
            tvRemoteClient: MockTVRemoteClient(),
            pairingClient: MockTVRemoteClient(),
            discoveryService: EmptyDiscoveryService()
        )

        #expect(state.savedDevice?.displayName == "Living Room")
        #expect(state.status == .failed(.missingPSK))
        #expect(state.error == .missingPSK)
        #expect(!state.remotePad.isEnabled)

        viewModel.openSettings()

        #expect(state.settings.tvName == "Living Room")
        #expect(state.settings.ipAddress == "192.168.1.2")
        #expect(state.settings.psk.isEmpty)
    }
}

@MainActor
private final class Harness {
    let state: RemotePageState
    let repository: MockDeviceRepository
    let client: MockTVRemoteClient
    let viewModel: RemotePageViewModel

    init(client: MockTVRemoteClient = MockTVRemoteClient()) {
        self.state = RemotePageState()
        self.repository = MockDeviceRepository()
        self.client = client
        self.viewModel = RemotePageViewModel(
            state: state,
            repository: repository,
            tvRemoteClient: client,
            pairingClient: client,
            discoveryService: EmptyDiscoveryService()
        )
    }

    func connectSavedDevice() async {
        state.settings.tvName = "Living Room"
        state.settings.ipAddress = "192.168.1.2"
        state.settings.psk = "1234"
        await viewModel.settings.testConnection()
        viewModel.saveSettings()
    }
}

@MainActor
private struct RemotePageSnapshot {
    let status: ConnectionStatus
    let title: String
    let subtitle: String
    let savedDevice: TVDevice?
    let isSettingsPresented: Bool
    let isRemoteEnabled: Bool

    init(state: RemotePageState) {
        self.status = state.status
        self.title = state.connection.title
        self.subtitle = state.connection.subtitle
        self.savedDevice = state.savedDevice
        self.isSettingsPresented = state.isSettingsPresented
        self.isRemoteEnabled = state.remotePad.isEnabled
    }
}

@MainActor
private func assertRemotePageStable(_ snapshot: RemotePageSnapshot, state: RemotePageState) {
    #expect(state.status == snapshot.status)
    #expect(state.connection.title == snapshot.title)
    #expect(state.connection.subtitle == snapshot.subtitle)
    #expect(state.savedDevice == snapshot.savedDevice)
    #expect(state.isSettingsPresented == snapshot.isSettingsPresented)
    #expect(state.remotePad.isEnabled == snapshot.isRemoteEnabled)
}

private final class MockDeviceRepository: DeviceRepository, @unchecked Sendable {
    private var device: TVDevice?
    private var secretByKey: [String: String] = [:]

    func stubDevice(psk: String?) {
        let device = TVDevice(name: "Living Room", host: "192.168.1.2", pskKey: "key")
        stubDevice(device, psk: psk)
    }

    func stubDevice(_ device: TVDevice, psk: String?) {
        self.device = device
        if let psk {
            self.secretByKey[device.pskKey] = psk
        }
    }

    func loadDevice() throws -> TVDevice? {
        device
    }

    func saveDevice(name: String, host: String, psk: String) throws -> TVDevice {
        try saveDevice(name: name, host: host, port: 80, psk: psk)
    }

    func saveDevice(name: String, host: String, port: Int, psk: String) throws -> TVDevice {
        try saveDevice(name: name, host: host, port: port, credential: .psk(psk), connectionMode: .psk)
    }

    func saveDevice(name: String, host: String, port: Int, credential: TVAuthCredential, connectionMode: ConnectionMode) throws -> TVDevice {
        let device = TVDevice(name: name, host: host, port: port, pskKey: "key", connectionMode: connectionMode)
        self.device = device
        secretByKey[device.pskKey] = credential.headerValue
        return device
    }

    func updateDeviceName(_ name: String, for device: TVDevice) throws -> TVDevice {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            return device
        }

        var updatedDevice = device
        updatedDevice.name = normalizedName
        self.device = updatedDevice
        return updatedDevice
    }

    func readCredential(for device: TVDevice) throws -> TVAuthCredential {
        guard let value = secretByKey[device.pskKey] else {
            throw RemoteControlError.missingPSK
        }
        switch device.connectionMode {
        case .psk:
            return .psk(value)
        case .normalPairing:
            return .cookie(value)
        }
    }

    func readPSK(for device: TVDevice) throws -> String {
        let credential = try readCredential(for: device)
        guard case .psk(let value) = credential else {
            throw RemoteControlError.missingPSK
        }
        return value
    }

    func deleteDevice() throws {
        if let device {
            secretByKey.removeValue(forKey: device.pskKey)
        }
        device = nil
    }
}

private final class MockSecretStore: SecretStore, @unchecked Sendable {
    private(set) var values: [String: String] = [:]

    func save(_ value: String, for key: String) throws {
        values[key] = value
    }

    func read(for key: String) throws -> String? {
        values[key]
    }

    func delete(for key: String) throws {
        values.removeValue(forKey: key)
    }

    func deleteAll() throws {
        values.removeAll()
    }
}

private final class MockTVRemoteClient: TVRemoteControlling, TVPairing, @unchecked Sendable {
    var connectionError: RemoteControlError?
    var commandAccessError: RemoteControlError?
    var sendError: RemoteControlError?
    var connectionDelayNanoseconds: UInt64
    var connectionResults: [RemoteControlError?]
    var fetchedDeviceName: String?
    private(set) var sentCommands: [RemoteCommand] = []

    init(
        connectionError: RemoteControlError? = nil,
        commandAccessError: RemoteControlError? = nil,
        sendError: RemoteControlError? = nil,
        connectionDelayNanoseconds: UInt64 = 0,
        connectionResults: [RemoteControlError?] = [],
        fetchedDeviceName: String? = nil
    ) {
        self.connectionError = connectionError
        self.commandAccessError = commandAccessError
        self.sendError = sendError
        self.connectionDelayNanoseconds = connectionDelayNanoseconds
        self.connectionResults = connectionResults
        self.fetchedDeviceName = fetchedDeviceName
    }

    func testConnection(device: TVDevice, credential: TVAuthCredential) async throws {
        if connectionDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: connectionDelayNanoseconds)
        }
        if !connectionResults.isEmpty {
            let result = connectionResults.removeFirst()
            if let result {
                throw result
            }
            return
        }
        if let connectionError {
            throw connectionError
        }
    }

    func testCommandAccess(device: TVDevice, credential: TVAuthCredential) async throws {
        if let commandAccessError {
            throw commandAccessError
        }
    }

    func send(command: RemoteCommand, device: TVDevice, credential: TVAuthCredential) async throws {
        sentCommands.append(command)
        if let sendError {
            throw sendError
        }
    }

    func sendText(_ text: String, device: TVDevice, credential: TVAuthCredential) async throws {
        if let sendError {
            throw sendError
        }
    }

    func fetchDeviceName(device: TVDevice, credential: TVAuthCredential) async throws -> String? {
        fetchedDeviceName
    }

    func initiatePairing(device: TVDevice, clientID: String) async throws -> String {
        return "mock-reg"
    }

    func confirmPairingPIN(device: TVDevice, registrationID: String, pin: String, clientID: String) async throws -> String {
        return "auth=mock-cookie"
    }

    func cancelPairing(clientID: String) async {
    }
}

private struct EmptyDiscoveryService: TVDiscoveryServicing {
    func discover(timeout: TimeInterval) -> AsyncThrowingStream<TVDiscoveryEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.finished([]))
            continuation.finish()
        }
    }
}

private struct FailingSaveDeviceMetadataStore: DeviceMetadataStore {
    let existingDevice: TVDevice

    func loadDevice() throws -> TVDevice? {
        existingDevice
    }

    func saveDevice(_ device: TVDevice) throws {
        throw RemoteControlError.keychainFailure("Unable to save the TV TV settings.")
    }

    func deleteDevice() throws {
    }
}
