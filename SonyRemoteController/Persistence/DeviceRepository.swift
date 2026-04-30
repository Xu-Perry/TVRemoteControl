import Foundation
import SonyRemoteCore

protocol DeviceRepository: Sendable {
    func loadDevice() throws -> SonyDevice?
    func saveDevice(name: String, host: String, psk: String) throws -> SonyDevice
    func readPSK(for device: SonyDevice) throws -> String
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
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let pskKey = "bravia-psk-\(UUID().uuidString)"
        let displayName = normalizedName.isEmpty ? normalizedHost : normalizedName
        let device = SonyDevice(
            name: displayName,
            host: normalizedHost,
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
        guard let psk = try secretStore.read(for: device.pskKey), !psk.isEmpty else {
            throw RemoteControlError.missingPSK
        }
        return psk
    }
}
