import Foundation
import SonyRemoteCore
import SonyRemoteNetworking

enum AppEnvironment {
    @MainActor
    static func makeRemotePageViewModel(state: RemotePageState) -> RemotePageViewModel {
        let processInfo = ProcessInfo.processInfo
        let repository: DeviceRepository
        let client: BRAVIAControlling

        if processInfo.environment["SONY_REMOTE_USE_MOCKS"] == "1" {
            repository = InMemoryDeviceRepository()
            client = MockBRAVIAClient(
                shouldFailConnection: processInfo.environment["SONY_REMOTE_MOCK_CONNECTION_FAILURE"] == "1"
            )
        } else {
            repository = LocalDeviceRepository()
            client = BRAVIAClient()
        }

        return RemotePageViewModel(
            state: state,
            repository: repository,
            braviaClient: client
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
        let pskKey = "mock-\(UUID().uuidString)"
        let savedDevice = SonyDevice(
            name: name.isEmpty ? host : name,
            host: host,
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
