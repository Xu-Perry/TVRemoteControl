import Foundation
import SonyRemoteCore
import SonyRemoteNetworking

enum AppEnvironment {
    @MainActor
    static func makeRemotePageViewModel(state: RemotePageState) -> RemotePageViewModel {
        let processInfo = ProcessInfo.processInfo
        let repository: DeviceRepository
        let client: BRAVIAControlling
        let pairingClient: BRAVIAPairing
        let discoveryService: BRAVIADiscoveryServicing

        if processInfo.environment["SONY_REMOTE_USE_MOCKS"] == "1" {
            let mockClient = MockBRAVIAClient(
                shouldFailConnection: processInfo.environment["SONY_REMOTE_MOCK_CONNECTION_FAILURE"] == "1"
            )
            repository = InMemoryDeviceRepository()
            client = mockClient
            pairingClient = mockClient
            discoveryService = MockBRAVIADiscoveryService()
        } else {
            let realClient = BRAVIAClient()
            repository = LocalDeviceRepository()
            client = realClient
            pairingClient = realClient
            discoveryService = BRAVIADiscoveryService()
        }

        return RemotePageViewModel(
            state: state,
            repository: repository,
            braviaClient: client,
            pairingClient: pairingClient,
            discoveryService: discoveryService,
            haptics: UIKitRemoteHaptics()
        )
    }
}

private final class InMemoryDeviceRepository: DeviceRepository, @unchecked Sendable {
    private var device: SonyDevice?
    private var secretByKey: [String: String] = [:]

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
        let pskKey = "mock-\(UUID().uuidString)"
        let savedDevice = SonyDevice(
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

private struct MockBRAVIAClient: BRAVIAControlling, BRAVIAPairing {
    let shouldFailConnection: Bool
    var shouldFailPairing: Bool = false
    var mockRegistrationID: String = "mock-reg-1234"
    var mockAuthCookie: String = "auth=mock-cookie-value"

    func testConnection(device: SonyDevice, credential: BRAVIAAuthCredential) async throws {
        if shouldFailConnection {
            throw RemoteControlError.unauthorized
        }
    }

    func send(command: RemoteCommand, device: SonyDevice, credential: BRAVIAAuthCredential) async throws {
    }

    func sendText(_ text: String, device: SonyDevice, credential: BRAVIAAuthCredential) async throws {
    }

    func initiatePairing(device: SonyDevice, clientID: String) async throws -> String {
        if shouldFailPairing {
            throw RemoteControlError.pairingFailed
        }
        return mockRegistrationID
    }

    func confirmPairingPIN(device: SonyDevice, registrationID: String, pin: String, clientID: String) async throws -> String {
        if pin == "0000" {
            throw RemoteControlError.pairingPinInvalid
        }
        return mockAuthCookie
    }

    func cancelPairing(clientID: String) async {
    }
}

private struct MockBRAVIADiscoveryService: BRAVIADiscoveryServicing {
    func discover(timeout: TimeInterval) -> AsyncThrowingStream<BRAVIADiscoveryEvent, Error> {
        AsyncThrowingStream { continuation in
            let devices = [
                DiscoveredBRAVIADevice(
                    name: "BRAVIA XR-65A80L",
                    host: "192.168.1.20",
                    uniqueIdentifier: "mock-xr-65a80l",
                    connectionReadiness: .connectable
                ),
                DiscoveredBRAVIADevice(
                    name: "BRAVIA KD-75X80K",
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
