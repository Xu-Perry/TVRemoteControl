import Foundation
import SonyRemoteCore

protocol DeviceRepository: Sendable {
    func loadDevice() throws -> SonyDevice?
    func saveDevice(name: String, host: String, psk: String) throws -> SonyDevice
    func saveDevice(name: String, host: String, port: Int, psk: String) throws -> SonyDevice
    func readPSK(for device: SonyDevice) throws -> String
    func deleteDevice() throws
}

struct LocalDeviceRepository: DeviceRepository {
    private let metadataStore: DeviceMetadataStore
    private let secretStore: SecretStore

    init(
        metadataStore: DeviceMetadataStore = UserDefaultsDeviceMetadataStore(),
        secretStore: SecretStore = KeychainSecretStore()
    ) {
        self.metadataStore = metadataStore
        self.secretStore = secretStore
    }

    func loadDevice() throws -> SonyDevice? {
        try metadataStore.loadDevice()
    }

    func saveDevice(name: String, host: String, psk: String) throws -> SonyDevice {
        try saveDevice(name: name, host: host, port: 80, psk: psk)
    }

    func saveDevice(name: String, host: String, port: Int, psk: String) throws -> SonyDevice {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let pskKey = "bravia-psk-\(UUID().uuidString)"
        let displayName = normalizedName.isEmpty ? normalizedHost : normalizedName
        let device = SonyDevice(
            name: displayName,
            host: normalizedHost,
            port: port,
            pskKey: pskKey,
            lastConnectedAt: Date()
        )
        try secretStore.save(psk, for: pskKey)
        do {
            try metadataStore.saveDevice(device)
        } catch {
            try? secretStore.delete(for: pskKey)
            throw error
        }
        return device
    }

    func readPSK(for device: SonyDevice) throws -> String {
        guard let psk = try secretStore.read(for: device.pskKey) else {
            throw RemoteControlError.missingPSK
        }
        return psk
    }

    func deleteDevice() throws {
        guard let device = try metadataStore.loadDevice() else {
            return
        }
        try metadataStore.deleteDevice()
        try secretStore.delete(for: device.pskKey)
    }
}
