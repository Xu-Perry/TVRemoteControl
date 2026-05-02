import Foundation
import Testing
import SonyRemoteCore
import SonyRemoteNetworking
@testable import SonyRemoteController

@MainActor
struct AutoConnectViewModelTests {
    @Test func scanShowsDevicesFoundAndDeduplicatesResults() async throws {
        let harness = AutoConnectHarness(discoveryEvents: [
            .deviceFound(.livingRoom),
            .deviceFound(.livingRoomDuplicate),
            .finished([.livingRoom])
        ])

        harness.viewModel.autoConnect.startScan()
        await Task.yield()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(harness.state.autoConnect.screen == .devicesFound)
        #expect(harness.state.autoConnect.discoveredDevices.count == 1)
        #expect(harness.state.autoConnect.discoveredDevices.first?.displayName == "BRAVIA XR-65A80L")
    }

    @Test func cancellingScanReturnsToFirstLaunchAndIgnoresLaterResults() async {
        let harness = AutoConnectHarness(discoveryEvents: [.deviceFound(.livingRoom)])

        harness.viewModel.autoConnect.startScan()
        harness.viewModel.autoConnect.cancelScan()
        await Task.yield()

        #expect(harness.state.autoConnect.screen == .firstLaunch)
        #expect(harness.state.autoConnect.discoveredDevices.isEmpty)
    }
}

@MainActor
final class AutoConnectHarness {
    let state: RemotePageState
    let repository: AutoConnectMockDeviceRepository
    let client: AutoConnectMockBRAVIAClient
    let discoveryService: AutoConnectFakeDiscoveryService
    let viewModel: RemotePageViewModel

    init(
        discoveryEvents: [BRAVIADiscoveryEvent] = [],
        connectionError: RemoteControlError? = nil
    ) {
        self.state = RemotePageState()
        self.repository = AutoConnectMockDeviceRepository()
        self.client = AutoConnectMockBRAVIAClient(connectionError: connectionError)
        self.discoveryService = AutoConnectFakeDiscoveryService(events: discoveryEvents)
        self.viewModel = RemotePageViewModel(
            state: state,
            repository: repository,
            braviaClient: client,
            pairingClient: client,
            discoveryService: discoveryService
        )
    }
}

final class AutoConnectMockDeviceRepository: DeviceRepository, @unchecked Sendable {
    private var device: SonyDevice?
    private var secretByKey: [String: String] = [:]

    func stubDevice(_ device: SonyDevice, psk: String? = "") {
        self.device = device
        if let psk {
            secretByKey[device.pskKey] = psk
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
        let device = SonyDevice(name: name, host: host, port: port, pskKey: "auto-key", connectionMode: connectionMode, lastConnectedAt: Date())
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

final class AutoConnectMockBRAVIAClient: BRAVIAControlling, BRAVIAPairing, @unchecked Sendable {
    let connectionError: RemoteControlError?
    private(set) var testedDevices: [SonyDevice] = []
    var mockRegistrationID = "mock-reg-1234"
    var mockAuthCookie = "auth=mock-cookie"

    init(connectionError: RemoteControlError? = nil) {
        self.connectionError = connectionError
    }

    func testConnection(device: SonyDevice, credential: BRAVIAAuthCredential) async throws {
        testedDevices.append(device)
        if let connectionError {
            throw connectionError
        }
    }

    func send(command: RemoteCommand, device: SonyDevice, credential: BRAVIAAuthCredential) async throws {
    }

    func initiatePairing(device: SonyDevice, clientID: String) async throws -> String {
        if let connectionError {
            throw connectionError
        }
        return mockRegistrationID
    }

    func confirmPairingPIN(device: SonyDevice, registrationID: String, pin: String, clientID: String) async throws -> String {
        return mockAuthCookie
    }

    func cancelPairing(clientID: String) async {
    }
}

final class AutoConnectFakeDiscoveryService: BRAVIADiscoveryServicing, @unchecked Sendable {
    var events: [BRAVIADiscoveryEvent]

    init(events: [BRAVIADiscoveryEvent]) {
        self.events = events
    }

    func discover(timeout: TimeInterval) -> AsyncThrowingStream<BRAVIADiscoveryEvent, Error> {
        AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}

extension DiscoveredBRAVIADevice {
    static let livingRoom = DiscoveredBRAVIADevice(
        name: "BRAVIA XR-65A80L",
        host: "192.168.1.20",
        uniqueIdentifier: "uuid:living-room",
        connectionReadiness: .connectable
    )

    static let livingRoomDuplicate = DiscoveredBRAVIADevice(
        name: "BRAVIA XR-65A80L",
        host: "192.168.1.20",
        uniqueIdentifier: "uuid:living-room",
        connectionReadiness: .connectable
    )
}
