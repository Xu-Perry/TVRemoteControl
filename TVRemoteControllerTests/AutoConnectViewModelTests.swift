import Foundation
import Testing
import TVRemoteCore
import TVRemoteNetworking
@testable import TVRemoteController

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
        #expect(harness.state.autoConnect.discoveredDevices.first?.displayName == "Living Room TV")
    }

    @Test func cancellingScanReturnsToFirstLaunchAndIgnoresLaterResults() async {
        let harness = AutoConnectHarness(discoveryEvents: [.deviceFound(.livingRoom)])

        harness.viewModel.autoConnect.startScan()
        harness.viewModel.autoConnect.cancelScan()
        await Task.yield()

        #expect(harness.state.autoConnect.screen == .firstLaunch)
        #expect(harness.state.autoConnect.discoveredDevices.isEmpty)
    }

    @Test func restartingScanWaitsForPreviousDiscoveryStreamToTerminate() async throws {
        let state = RemotePageState()
        let repository = AutoConnectMockDeviceRepository()
        let client = AutoConnectMockTVRemoteClient()
        let discoveryService = AutoConnectTrackingDiscoveryService()
        let viewModel = RemotePageViewModel(
            state: state,
            repository: repository,
            tvRemoteClient: client,
            pairingClient: client,
            discoveryService: discoveryService
        )

        viewModel.autoConnect.startScan()
        try await discoveryService.waitForStartedCount(1)
        viewModel.autoConnect.startScan()
        try await discoveryService.waitForStartedCount(2)

        #expect(discoveryService.maxActiveStreams == 1)
        #expect(discoveryService.terminationCount >= 1)

        viewModel.autoConnect.cancelScan()
    }
}

@MainActor
final class AutoConnectHarness {
    let state: RemotePageState
    let repository: AutoConnectMockDeviceRepository
    let client: AutoConnectMockTVRemoteClient
    let discoveryService: AutoConnectFakeDiscoveryService
    let viewModel: RemotePageViewModel

    init(
        discoveryEvents: [TVDiscoveryEvent] = [],
        discoveryError: Error? = nil,
        connectionError: RemoteControlError? = nil
    ) {
        self.state = RemotePageState()
        self.repository = AutoConnectMockDeviceRepository()
        self.client = AutoConnectMockTVRemoteClient(connectionError: connectionError)
        self.discoveryService = AutoConnectFakeDiscoveryService(events: discoveryEvents, error: discoveryError)
        self.viewModel = RemotePageViewModel(
            state: state,
            repository: repository,
            tvRemoteClient: client,
            pairingClient: client,
            discoveryService: discoveryService
        )
    }
}

final class AutoConnectMockDeviceRepository: DeviceRepository, @unchecked Sendable {
    private var device: TVDevice?
    private var secretByKey: [String: String] = [:]

    func stubDevice(_ device: TVDevice, psk: String? = "") {
        self.device = device
        if let psk {
            secretByKey[device.pskKey] = psk
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
        let device = TVDevice(name: name, host: host, port: port, pskKey: "auto-key", connectionMode: connectionMode, lastConnectedAt: Date())
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

final class AutoConnectMockTVRemoteClient: TVRemoteControlling, TVPairing, @unchecked Sendable {
    let connectionError: RemoteControlError?
    private(set) var testedDevices: [TVDevice] = []
    var mockRegistrationID = "mock-reg-1234"
    var mockAuthCookie = "auth=mock-cookie"

    init(connectionError: RemoteControlError? = nil) {
        self.connectionError = connectionError
    }

    func testConnection(device: TVDevice, credential: TVAuthCredential) async throws {
        testedDevices.append(device)
        if let connectionError {
            throw connectionError
        }
    }

    func send(command: RemoteCommand, device: TVDevice, credential: TVAuthCredential) async throws {
    }

    func sendText(_ text: String, device: TVDevice, credential: TVAuthCredential) async throws {
    }

    func initiatePairing(device: TVDevice, clientID: String) async throws -> String {
        if let connectionError {
            throw connectionError
        }
        return mockRegistrationID
    }

    func confirmPairingPIN(device: TVDevice, registrationID: String, pin: String, clientID: String) async throws -> String {
        return mockAuthCookie
    }

    func cancelPairing(clientID: String) async {
    }
}

final class AutoConnectFakeDiscoveryService: TVDiscoveryServicing, @unchecked Sendable {
    var events: [TVDiscoveryEvent]
    var error: Error?

    init(events: [TVDiscoveryEvent], error: Error? = nil) {
        self.events = events
        self.error = error
    }

    func discover(timeout: TimeInterval) -> AsyncThrowingStream<TVDiscoveryEvent, Error> {
        AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            if let error {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }
    }
}

final class AutoConnectTrackingDiscoveryService: TVDiscoveryServicing, @unchecked Sendable {
    private let queue = DispatchQueue(label: "AutoConnectTrackingDiscoveryService")
    private var startedCount = 0
    private var activeStreams = 0
    private var maximumActiveStreams = 0
    private var terminations = 0

    var maxActiveStreams: Int {
        queue.sync { maximumActiveStreams }
    }

    var terminationCount: Int {
        queue.sync { terminations }
    }

    func discover(timeout: TimeInterval) -> AsyncThrowingStream<TVDiscoveryEvent, Error> {
        AsyncThrowingStream { continuation in
            queue.sync {
                startedCount += 1
                activeStreams += 1
                maximumActiveStreams = max(maximumActiveStreams, activeStreams)
            }
            continuation.yield(.deviceFound(.livingRoom))
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                queue.sync {
                    self.activeStreams -= 1
                    self.terminations += 1
                }
            }
        }
    }

    func waitForStartedCount(_ expectedCount: Int) async throws {
        for _ in 0..<100 {
            if queue.sync(execute: { startedCount >= expectedCount }) {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("Timed out waiting for discovery start count \(expectedCount)")
    }
}

extension DiscoveredTVDevice {
    static let livingRoom = DiscoveredTVDevice(
        name: "Living Room TV",
        host: "192.168.1.20",
        uniqueIdentifier: "uuid:living-room",
        connectionReadiness: .connectable
    )

    static let livingRoomDuplicate = DiscoveredTVDevice(
        name: "Living Room TV",
        host: "192.168.1.20",
        uniqueIdentifier: "uuid:living-room",
        connectionReadiness: .connectable
    )
}
