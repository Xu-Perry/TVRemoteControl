import Foundation
import Testing
import SonyRemoteCore
import SonyRemoteNetworking
@testable import SonyRemoteController

@MainActor
struct SonyRemoteControllerTests {
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
        #expect(harness.state.settings.pskRequired == false)
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

    @Test func manualConnectionReprobesWhenIPChangesAfterPSKRequirement() async {
        let harness = Harness(client: MockBRAVIAClient(connectionResults: [.unauthorized, nil]))
        harness.state.settings.ipAddress = "192.168.1.2"

        await harness.viewModel.settings.testConnection()
        #expect(harness.state.settings.pskRequired == true)
        #expect(!harness.state.settings.canSave)

        harness.state.settings.ipAddress = "192.168.1.3"
        harness.state.settings.psk = "1234"
        await harness.viewModel.settings.testConnection()

        #expect(harness.state.settings.pskRequired == false)
        #expect(harness.state.settings.lastTestedHost == "192.168.1.3")
        #expect(harness.state.settings.canSave)
        #expect(harness.state.settings.error == nil)
    }

    @Test func commandFailureShowsErrorBannerState() async {
        let harness = Harness(client: MockBRAVIAClient(sendError: .timeout))
        await harness.connectSavedDevice()

        await harness.viewModel.remotePad.send(.home)

        #expect(harness.state.error == .timeout)
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

    @Test func failedCommandSendKeepsConnectedRemotePageStable() async {
        let harness = Harness(client: MockBRAVIAClient(sendError: .timeout))
        await harness.connectSavedDevice()
        let stableState = RemotePageSnapshot(state: harness.state)

        await harness.viewModel.remotePad.send(.home)

        #expect(harness.client.sentCommands == [.home])
        #expect(harness.state.error == .timeout)
        #expect(!harness.state.remotePad.isSendingCommand)
        assertRemotePageStable(stableState, state: harness.state)
    }

    @Test func failedCommandSendDoesNotReplaceLastSuccessfulCommand() async {
        let harness = Harness(client: MockBRAVIAClient(sendError: .timeout))
        await harness.connectSavedDevice()
        harness.state.remotePad.lastCommand = .up

        await harness.viewModel.remotePad.send(.home)

        #expect(harness.state.remotePad.lastCommand == .up)
        #expect(harness.state.error == .timeout)
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
        let encodedMetadata = try #require(try metadataSecretStore.read(for: "saved.bravia.device"))
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
        let existingDevice = SonyDevice(name: "Living Room", host: "192.168.1.2", pskKey: "old-key")
        let metadataStore = FailingSaveDeviceMetadataStore(existingDevice: existingDevice)
        let secretStore = MockSecretStore()
        try secretStore.save("old-psk", for: existingDevice.pskKey)
        let repository = LocalDeviceRepository(metadataStore: metadataStore, secretStore: secretStore)

        #expect(throws: RemoteControlError.keychainFailure("Unable to save the BRAVIA TV settings.")) {
            try repository.saveDevice(name: "Bedroom", host: "192.168.1.3", psk: "new-psk")
        }
        #expect(try secretStore.read(for: existingDevice.pskKey) == "old-psk")
        #expect(secretStore.values.count == 1)
    }

    @Test func keychainMetadataStoreMigratesLegacyUserDefaultsDevice() throws {
        let suiteName = "SonyRemoteControllerTests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let legacyStore = UserDefaultsDeviceMetadataStore(userDefaults: userDefaults, key: "savedDevice")
        let metadataSecretStore = MockSecretStore()
        let savedDevice = SonyDevice(name: "Living Room", host: "192.168.1.2", pskKey: "key")
        try legacyStore.saveDevice(savedDevice)

        let metadataStore = KeychainDeviceMetadataStore(
            secretStore: metadataSecretStore,
            key: "saved.bravia.device",
            legacyStore: legacyStore
        )

        let restoredDevice = try #require(try metadataStore.loadDevice())

        #expect(restoredDevice == savedDevice)
        #expect(try metadataSecretStore.read(for: "saved.bravia.device") != nil)
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

    @Test func restoresPersistedDeviceIntoUsableRemoteState() async throws {
        let state = RemotePageState()
        let repository = MockDeviceRepository()
        repository.stubDevice(psk: "1234")

        _ = RemotePageViewModel(
            state: state,
            repository: repository,
            braviaClient: MockBRAVIAClient(connectionDelayNanoseconds: 50_000_000),
            pairingClient: MockBRAVIAClient(),
            discoveryService: EmptyDiscoveryService()
        )

        #expect(state.status == .connecting)
        #expect(!state.remotePad.isEnabled)
        try await waitUntil { state.status == .connected }

        #expect(state.savedDevice?.displayName == "Living Room")
        #expect(state.status == .connected)
        #expect(state.remotePad.isEnabled)
        #expect(state.connection.title == "Living Room")
    }

    @Test func restoredPersistedDeviceRequiresReachabilityBeforeEnablingRemote() async throws {
        let state = RemotePageState()
        let repository = MockDeviceRepository()
        repository.stubDevice(psk: "1234")

        _ = RemotePageViewModel(
            state: state,
            repository: repository,
            braviaClient: MockBRAVIAClient(connectionError: .unreachable, connectionDelayNanoseconds: 50_000_000),
            pairingClient: MockBRAVIAClient(),
            discoveryService: EmptyDiscoveryService()
        )

        #expect(state.savedDevice?.displayName == "Living Room")
        #expect(state.status == .connecting)
        #expect(!state.remotePad.isEnabled)
        #expect(!state.isAutoConnectPresented)

        try await waitUntil { state.status == .failed(.unreachable) }

        #expect(state.savedDevice?.displayName == "Living Room")
        #expect(state.status == .failed(.unreachable))
        #expect(!state.remotePad.isEnabled)
        #expect(!state.isAutoConnectPresented)
        #expect(state.connection.title == "Living Room")
        #expect(state.connection.subtitle == ConnectionStatus.failed(.unreachable).displayText)
    }

    @Test func missingPersistedPSKRetainsDeviceAndShowsRecoveryError() {
        let state = RemotePageState()
        let repository = MockDeviceRepository()
        repository.stubDevice(psk: nil)

        let viewModel = RemotePageViewModel(
            state: state,
            repository: repository,
            braviaClient: MockBRAVIAClient(),
            pairingClient: MockBRAVIAClient(),
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
    let client: MockBRAVIAClient
    let viewModel: RemotePageViewModel

    init(client: MockBRAVIAClient = MockBRAVIAClient()) {
        self.state = RemotePageState()
        self.repository = MockDeviceRepository()
        self.client = client
        self.viewModel = RemotePageViewModel(
            state: state,
            repository: repository,
            braviaClient: client,
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
    let savedDevice: SonyDevice?
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
    private var device: SonyDevice?
    private var secretByKey: [String: String] = [:]

    func stubDevice(psk: String?) {
        let device = SonyDevice(name: "Living Room", host: "192.168.1.2", pskKey: "key")
        self.device = device
        if let psk {
            self.secretByKey[device.pskKey] = psk
        }
    }

    func loadDevice() throws -> SonyDevice? {
        device
    }

    func saveDevice(name: String, host: String, psk: String) throws -> SonyDevice {
        try saveDevice(name: name, host: host, port: 80, psk: psk)
    }

    func saveDevice(name: String, host: String, port: Int, psk: String) throws -> SonyDevice {
        try saveDevice(name: name, host: host, port: port, credential: .psk(psk), connectionMode: .psk)
    }

    func saveDevice(name: String, host: String, port: Int, credential: BRAVIAAuthCredential, connectionMode: ConnectionMode) throws -> SonyDevice {
        let device = SonyDevice(name: name, host: host, port: port, pskKey: "key", connectionMode: connectionMode)
        self.device = device
        secretByKey[device.pskKey] = credential.headerValue
        return device
    }

    func readCredential(for device: SonyDevice) throws -> BRAVIAAuthCredential {
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

    func readPSK(for device: SonyDevice) throws -> String {
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

private final class MockBRAVIAClient: BRAVIAControlling, BRAVIAPairing, @unchecked Sendable {
    var connectionError: RemoteControlError?
    var sendError: RemoteControlError?
    var connectionDelayNanoseconds: UInt64
    var connectionResults: [RemoteControlError?]
    private(set) var sentCommands: [RemoteCommand] = []

    init(
        connectionError: RemoteControlError? = nil,
        sendError: RemoteControlError? = nil,
        connectionDelayNanoseconds: UInt64 = 0,
        connectionResults: [RemoteControlError?] = []
    ) {
        self.connectionError = connectionError
        self.sendError = sendError
        self.connectionDelayNanoseconds = connectionDelayNanoseconds
        self.connectionResults = connectionResults
    }

    func testConnection(device: SonyDevice, credential: BRAVIAAuthCredential) async throws {
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

    func send(command: RemoteCommand, device: SonyDevice, credential: BRAVIAAuthCredential) async throws {
        sentCommands.append(command)
        if let sendError {
            throw sendError
        }
    }

    func sendText(_ text: String, device: SonyDevice, credential: BRAVIAAuthCredential) async throws {
        if let sendError {
            throw sendError
        }
    }

    func initiatePairing(device: SonyDevice, clientID: String) async throws -> String {
        return "mock-reg"
    }

    func confirmPairingPIN(device: SonyDevice, registrationID: String, pin: String, clientID: String) async throws -> String {
        return "auth=mock-cookie"
    }

    func cancelPairing(clientID: String) async {
    }
}

private struct EmptyDiscoveryService: BRAVIADiscoveryServicing {
    func discover(timeout: TimeInterval) -> AsyncThrowingStream<BRAVIADiscoveryEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.finished([]))
            continuation.finish()
        }
    }
}

private struct FailingSaveDeviceMetadataStore: DeviceMetadataStore {
    let existingDevice: SonyDevice

    func loadDevice() throws -> SonyDevice? {
        existingDevice
    }

    func saveDevice(_ device: SonyDevice) throws {
        throw RemoteControlError.keychainFailure("Unable to save the BRAVIA TV settings.")
    }

    func deleteDevice() throws {
    }
}
