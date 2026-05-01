import Foundation
import SonyRemoteCore
import SonyRemoteNetworking

enum AppEnvironment {
    @MainActor
    static func makeRemotePageViewModel(state: RemotePageState) -> RemotePageViewModel {
        let processInfo = ProcessInfo.processInfo
        let repository: DeviceRepository
        let client: BRAVIAControlling
        let discoveryService: BRAVIADiscoveryServicing

        if processInfo.environment["SONY_REMOTE_USE_MOCKS"] == "1" {
            repository = InMemoryDeviceRepository()
            client = MockBRAVIAClient(
                shouldFailConnection: processInfo.environment["SONY_REMOTE_MOCK_CONNECTION_FAILURE"] == "1"
            )
            discoveryService = MockBRAVIADiscoveryService()
        } else {
            repository = LocalDeviceRepository()
            client = BRAVIAClient()
            discoveryService = BRAVIADiscoveryService()
        }

        return RemotePageViewModel(
            state: state,
            repository: repository,
            braviaClient: client,
            discoveryService: discoveryService
        )
    }
}

private final class InMemoryDeviceRepository: DeviceRepository, @unchecked Sendable {
    private var device: SonyDevice?
    private var pskByKey: [String: String] = [:]

    func loadDevice() throws -> SonyDevice? {
        device
    }

    func saveDevice(name: String, host: String, psk: String) throws -> SonyDevice {
        try saveDevice(name: name, host: host, port: 80, psk: psk)
    }

    func saveDevice(name: String, host: String, port: Int, psk: String) throws -> SonyDevice {
        let pskKey = "mock-\(UUID().uuidString)"
        let savedDevice = SonyDevice(
            name: name.isEmpty ? host : name,
            host: host,
            port: port,
            pskKey: pskKey,
            lastConnectedAt: Date()
        )
        device = savedDevice
        pskByKey[pskKey] = psk
        return savedDevice
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

private struct MockBRAVIAClient: BRAVIAControlling {
    let shouldFailConnection: Bool

    func testConnection(device: SonyDevice, psk: String) async throws {
        if shouldFailConnection {
            throw RemoteControlError.unauthorized
        }
    }

    func send(command: RemoteCommand, device: SonyDevice, psk: String) async throws {
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
