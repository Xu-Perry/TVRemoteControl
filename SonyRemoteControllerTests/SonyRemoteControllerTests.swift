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
        #expect(harness.state.settings.successMessage == "Connection succeeded.")
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
        let suiteName = "SonyRemoteControllerTests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let secretStore = MockSecretStore()
        let metadataStore = UserDefaultsDeviceMetadataStore(userDefaults: userDefaults, key: "savedDevice")
        let repository = LocalDeviceRepository(metadataStore: metadataStore, secretStore: secretStore)

        let savedDevice = try repository.saveDevice(
            name: " Living Room ",
            host: " 192.168.1.2 ",
            psk: "1234"
        )

        let restoredRepository = LocalDeviceRepository(
            metadataStore: UserDefaultsDeviceMetadataStore(userDefaults: userDefaults, key: "savedDevice"),
            secretStore: secretStore
        )
        let restoredDevice = try #require(try restoredRepository.loadDevice())
        let rawMetadata = try #require(userDefaults.data(forKey: "savedDevice"))
        let rawMetadataText = String(decoding: rawMetadata, as: UTF8.self)

        #expect(restoredDevice == savedDevice)
        #expect(restoredDevice.name == "Living Room")
        #expect(restoredDevice.host == "192.168.1.2")
        #expect(try restoredRepository.readPSK(for: restoredDevice) == "1234")
        #expect(rawMetadataText.contains(restoredDevice.pskKey))
        #expect(!rawMetadataText.contains("1234"))
    }

    @Test func restoresPersistedDeviceIntoUsableRemoteState() {
        let state = RemotePageState()
        let repository = MockDeviceRepository()
        repository.stubDevice(psk: "1234")

        _ = RemotePageViewModel(
            state: state,
            repository: repository,
            braviaClient: MockBRAVIAClient()
        )

        #expect(state.savedDevice?.displayName == "Living Room")
        #expect(state.status == .connected)
        #expect(state.remotePad.isEnabled)
        #expect(state.connection.title == "Living Room")
    }

    @Test func missingPersistedPSKRetainsDeviceAndShowsRecoveryError() {
        let state = RemotePageState()
        let repository = MockDeviceRepository()
        repository.stubDevice(psk: nil)

        let viewModel = RemotePageViewModel(
            state: state,
            repository: repository,
            braviaClient: MockBRAVIAClient()
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
            braviaClient: client
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
    // Command progress must not churn broad page state that drives header/layout identity.
    #expect(state.status == snapshot.status)
    #expect(state.connection.title == snapshot.title)
    #expect(state.connection.subtitle == snapshot.subtitle)
    #expect(state.savedDevice == snapshot.savedDevice)
    #expect(state.isSettingsPresented == snapshot.isSettingsPresented)
    #expect(state.remotePad.isEnabled == snapshot.isRemoteEnabled)
}

private final class MockDeviceRepository: DeviceRepository, @unchecked Sendable {
    private var device: SonyDevice?
    private var pskByKey: [String: String] = [:]

    func stubDevice(psk: String?) {
        let device = SonyDevice(name: "Living Room", host: "192.168.1.2", pskKey: "key")
        self.device = device
        if let psk {
            self.pskByKey[device.pskKey] = psk
        }
    }

    func loadDevice() throws -> SonyDevice? {
        device
    }

    func saveDevice(name: String, host: String, psk: String) throws -> SonyDevice {
        let device = SonyDevice(name: name, host: host, pskKey: "key")
        self.device = device
        self.pskByKey[device.pskKey] = psk
        return device
    }

    func readPSK(for device: SonyDevice) throws -> String {
        guard let psk = pskByKey[device.pskKey] else {
            throw RemoteControlError.missingPSK
        }
        return psk
    }
}

private final class MockSecretStore: SecretStore, @unchecked Sendable {
    private var values: [String: String] = [:]

    func save(_ value: String, for key: String) throws {
        values[key] = value
    }

    func read(for key: String) throws -> String? {
        values[key]
    }

    func delete(for key: String) throws {
        values.removeValue(forKey: key)
    }
}

private final class MockBRAVIAClient: BRAVIAControlling, @unchecked Sendable {
    var connectionError: RemoteControlError?
    var sendError: RemoteControlError?
    private(set) var sentCommands: [RemoteCommand] = []

    init(connectionError: RemoteControlError? = nil, sendError: RemoteControlError? = nil) {
        self.connectionError = connectionError
        self.sendError = sendError
    }

    func testConnection(device: SonyDevice, psk: String) async throws {
        if let connectionError {
            throw connectionError
        }
    }

    func send(command: RemoteCommand, device: SonyDevice, psk: String) async throws {
        sentCommands.append(command)
        if let sendError {
            throw sendError
        }
    }
}
