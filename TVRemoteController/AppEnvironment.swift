import Foundation
import TVRemoteCore
import TVRemoteNetworking

enum AppEnvironment {
    @MainActor
    static func makeRemotePageViewModel(state: RemotePageState) -> RemotePageViewModel {
        let processInfo = ProcessInfo.processInfo
        let repository: DeviceRepository
        let client: TVRemoteControlling
        let pairingClient: TVPairing
        let discoveryService: TVDiscoveryServicing

        if processInfo.environment["TV_REMOTE_USE_MOCKS"] == "1" {
            let mockClient = MockTVRemoteClient(
                shouldFailConnection: processInfo.environment["TV_REMOTE_MOCK_CONNECTION_FAILURE"] == "1"
            )
            repository = InMemoryDeviceRepository()
            client = mockClient
            pairingClient = mockClient
            discoveryService = MockTVDiscoveryService()
        } else {
            let realClient = TVRemoteClient()
            repository = LocalDeviceRepository()
            client = realClient
            pairingClient = realClient
            discoveryService = TVDiscoveryService()
        }

        return RemotePageViewModel(
            state: state,
            repository: repository,
            tvRemoteClient: client,
            pairingClient: pairingClient,
            discoveryService: discoveryService,
            haptics: UIKitRemoteHaptics()
        )
    }
}

private final class InMemoryDeviceRepository: DeviceRepository, @unchecked Sendable {
    private var device: TVDevice?
    private var secretByKey: [String: String] = [:]

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
        // Clean up old PSK before writing new one to stay consistent with LocalDeviceRepository.
        if let existing = device {
            secretByKey.removeValue(forKey: existing.pskKey)
        }

        let pskKey = "mock-\(UUID().uuidString)"
        let savedDevice = TVDevice(
            name: name.isEmpty ? host : name,
            host: host,
            port: port,
            pskKey: pskKey,
            connectionMode: connectionMode,
            lastConnectedAt: Date()
        )
        device = savedDevice
        secretByKey[pskKey] = credential.headerValue
        return savedDevice
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
        device = nil
        secretByKey.removeAll()
    }
}

private struct MockTVRemoteClient: TVRemoteControlling, TVPairing {
    let shouldFailConnection: Bool
    var shouldFailPairing: Bool = false
    var mockRegistrationID: String = "mock-reg-1234"
    var mockAuthCookie: String = "auth=mock-cookie-value"

    func testConnection(device: TVDevice, credential: TVAuthCredential) async throws {
        if shouldFailConnection {
            throw RemoteControlError.unauthorized
        }
    }

    func send(command: RemoteCommand, device: TVDevice, credential: TVAuthCredential) async throws {
    }

    func sendText(_ text: String, device: TVDevice, credential: TVAuthCredential) async throws {
    }

    func initiatePairing(device: TVDevice, clientID: String) async throws -> String {
        if shouldFailPairing {
            throw RemoteControlError.pairingFailed
        }
        return mockRegistrationID
    }

    func confirmPairingPIN(device: TVDevice, registrationID: String, pin: String, clientID: String) async throws -> String {
        if pin == "0000" {
            throw RemoteControlError.pairingPinInvalid
        }
        return mockAuthCookie
    }

    func cancelPairing(clientID: String) async {
    }
}

private struct MockTVDiscoveryService: TVDiscoveryServicing {
    func discover(timeout: TimeInterval) -> AsyncThrowingStream<TVDiscoveryEvent, Error> {
        AsyncThrowingStream { continuation in
            let devices = [
                DiscoveredTVDevice(
                    name: "Living Room TV",
                    host: "192.168.1.20",
                    uniqueIdentifier: "mock-xr-65a80l",
                    connectionReadiness: .connectable
                ),
                DiscoveredTVDevice(
                    name: "Bedroom TV",
                    host: "192.168.1.21",
                    uniqueIdentifier: "mock-kd-75x80k",
                    connectionReadiness: .paired
                )
            ]
            continuation.yield(.finished(devices))
            continuation.finish()
        }
    }
}
