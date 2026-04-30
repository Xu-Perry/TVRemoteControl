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
        harness.state.settings.tvName = "Living Room"
        harness.state.settings.ipAddress = "192.168.1.2"
        harness.state.settings.psk = "1234"
        await harness.viewModel.settings.testConnection()
        harness.viewModel.saveSettings()

        await harness.viewModel.remotePad.send(.home)

        #expect(harness.state.error == .timeout)
        #expect(harness.state.remotePad.lastCommand == nil)
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
    let viewModel: RemotePageViewModel

    init(client: MockBRAVIAClient = MockBRAVIAClient()) {
        self.state = RemotePageState()
        self.repository = MockDeviceRepository()
        self.viewModel = RemotePageViewModel(
            state: state,
            repository: repository,
            braviaClient: client
        )
    }
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

private struct MockBRAVIAClient: BRAVIAControlling {
    var connectionError: RemoteControlError?
    var sendError: RemoteControlError?

    func testConnection(device: SonyDevice, psk: String) async throws {
        if let connectionError {
            throw connectionError
        }
    }

    func send(command: RemoteCommand, device: SonyDevice, psk: String) async throws {
        if let sendError {
            throw sendError
        }
    }
}
