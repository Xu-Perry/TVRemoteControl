import Foundation
import TVRemoteCore

protocol DeviceRepository: Sendable {
    func loadDevice() throws -> TVDevice?
    func saveDevice(name: String, host: String, psk: String) throws -> TVDevice
    func saveDevice(name: String, host: String, port: Int, psk: String) throws -> TVDevice
    func saveDevice(name: String, host: String, port: Int, credential: TVAuthCredential, connectionMode: ConnectionMode) throws -> TVDevice
    func updateDeviceName(_ name: String, for device: TVDevice) throws -> TVDevice
    func readCredential(for device: TVDevice) throws -> TVAuthCredential
    func readPSK(for device: TVDevice) throws -> String
    func deleteDevice() throws
}

struct LocalDeviceRepository: DeviceRepository {
    private let metadataStore: DeviceMetadataStore
    private let secretStore: SecretStore

    init(
        metadataStore: DeviceMetadataStore = KeychainDeviceMetadataStore(),
        secretStore: SecretStore = KeychainSecretStore()
    ) {
        self.metadataStore = metadataStore
        self.secretStore = secretStore
    }

    func loadDevice() throws -> TVDevice? {
        try metadataStore.loadDevice()
    }

    func saveDevice(name: String, host: String, psk: String) throws -> TVDevice {
        try saveDevice(name: name, host: host, port: 80, psk: psk)
    }

    func saveDevice(name: String, host: String, port: Int, psk: String) throws -> TVDevice {
        try saveDevice(name: name, host: host, port: port, credential: .psk(psk), connectionMode: .psk)
    }

    func saveDevice(name: String, host: String, port: Int, credential: TVAuthCredential, connectionMode: ConnectionMode) throws -> TVDevice {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let pskKey = secretKey(connectionMode: connectionMode)
        let displayName = normalizedName.isEmpty ? normalizedHost : normalizedName

        let existingPSKKey = try? metadataStore.loadDevice()?.pskKey

        let device = TVDevice(
            name: displayName,
            host: normalizedHost,
            port: port,
            pskKey: pskKey,
            connectionMode: connectionMode,
            lastConnectedAt: Date()
        )
        try secretStore.save(credential.headerValue, for: pskKey)
        do {
            try metadataStore.saveDevice(device)
        } catch {
            try? secretStore.delete(for: pskKey)
            throw error
        }
        if let existingPSKKey, existingPSKKey != pskKey {
            try? secretStore.delete(for: existingPSKKey)
        }
        return device
    }

    func updateDeviceName(_ name: String, for device: TVDevice) throws -> TVDevice {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            return device
        }

        var updatedDevice = device
        updatedDevice.name = normalizedName
        try metadataStore.saveDevice(updatedDevice)
        return updatedDevice
    }

    func readCredential(for device: TVDevice) throws -> TVAuthCredential {
        guard let value = try secretStore.read(for: device.pskKey) else {
            throw RemoteControlError.missingPSK
        }
        // Allow empty credentials — some TVs don't require PSK authentication.
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
        try metadataStore.deleteDevice()
        try secretStore.deleteAll()
    }

    private func secretKey(connectionMode: ConnectionMode) -> String {
        switch connectionMode {
        case .psk:
            return "tv-psk-\(UUID().uuidString)"
        case .normalPairing:
            return "tv-cookie-\(UUID().uuidString)"
        }
    }
}
