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
            discoveryService: discoveryService
        )
    }
}

final class AutoConnectMockDeviceRepository: DeviceRepository, @unchecked Sendable {
    private var device: SonyDevice?
    private var pskByKey: [String: String] = [:]

    func stubDevice(_ device: SonyDevice, psk: String? = "") {
        self.device = device
        if let psk {
            pskByKey[device.pskKey] = psk
        }
    }

    func loadDevice() throws -> SonyDevice? {
        device
    }

    func saveDevice(name: String, host: String, psk: String) throws -> SonyDevice {
        try saveDevice(name: name, host: host, port: 80, psk: psk)
    }

    func saveDevice(name: String, host: String, port: Int, psk: String) throws -> SonyDevice {
        let device = SonyDevice(name: name, host: host, port: port, pskKey: "auto-key", lastConnectedAt: Date())
        self.device = device
        pskByKey[device.pskKey] = psk
        return device
    }

    func readPSK(for device: SonyDevice) throws -> String {
        guard let psk = pskByKey[device.pskKey] else {
            throw RemoteControlError.missingPSK
        }
        return psk
    }

    func deleteDevice() throws {
        if let device {
            pskByKey.removeValue(forKey: device.pskKey)
        }
        device = nil
    }
}

final class AutoConnectMockBRAVIAClient: BRAVIAControlling, @unchecked Sendable {
    let connectionError: RemoteControlError?
    private(set) var testedDevices: [SonyDevice] = []

    init(connectionError: RemoteControlError? = nil) {
        self.connectionError = connectionError
    }

    func testConnection(device: SonyDevice, psk: String) async throws {
        testedDevices.append(device)
        if let connectionError {
            throw connectionError
        }
    }

    func send(command: RemoteCommand, device: SonyDevice, psk: String) async throws {
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
