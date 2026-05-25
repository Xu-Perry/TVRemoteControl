import Foundation
import TVRemoteCore

protocol DeviceMetadataStore: Sendable {
    func loadDevice() throws -> TVDevice?
    func saveDevice(_ device: TVDevice) throws
    func deleteDevice() throws
}

struct KeychainDeviceMetadataStore: DeviceMetadataStore {
    private let secretStore: SecretStore
    private let key: String
    private let legacyStore: DeviceMetadataStore?

    init(
        secretStore: SecretStore = KeychainSecretStore(service: "com.perry.TVRemoteController.device"),
        key: String = "saved.tv.device",
        legacyStore: DeviceMetadataStore? = UserDefaultsDeviceMetadataStore()
    ) {
        self.secretStore = secretStore
        self.key = key
        self.legacyStore = legacyStore
    }

    func loadDevice() throws -> TVDevice? {
        if let value = try secretStore.read(for: key), !value.isEmpty {
            return try decodeDevice(from: value)
        }

        guard let legacyDevice = try legacyStore?.loadDevice() else {
            return nil
        }

        try saveDevice(legacyDevice)
        try? legacyStore?.deleteDevice()
        return legacyDevice
    }

    func saveDevice(_ device: TVDevice) throws {
        let data = try JSONEncoder().encode(device)
        try secretStore.save(data.base64EncodedString(), for: key)
        try? legacyStore?.deleteDevice()
    }

    func deleteDevice() throws {
        try secretStore.delete(for: key)
        try legacyStore?.deleteDevice()
    }

    private func decodeDevice(from value: String) throws -> TVDevice {
        guard let data = Data(base64Encoded: value) else {
            throw RemoteControlError.keychainFailure("Unable to read the saved TV TV settings.")
        }

        do {
            return try JSONDecoder().decode(TVDevice.self, from: data)
        } catch {
            throw RemoteControlError.keychainFailure("Unable to decode the saved TV TV settings.")
        }
    }
}

struct UserDefaultsDeviceMetadataStore: DeviceMetadataStore {
    private let userDefaults: UserDefaults
    private let key: String

    init(userDefaults: UserDefaults = .standard, key: String = "saved.tv.device") {
        self.userDefaults = userDefaults
        self.key = key
    }

    func loadDevice() throws -> TVDevice? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        return try JSONDecoder().decode(TVDevice.self, from: data)
    }

    func saveDevice(_ device: TVDevice) throws {
        let data = try JSONEncoder().encode(device)
        userDefaults.set(data, forKey: key)
        userDefaults.synchronize()

        guard let savedData = userDefaults.data(forKey: key) else {
            throw RemoteControlError.keychainFailure("Unable to save the TV TV settings.")
        }

        _ = try JSONDecoder().decode(TVDevice.self, from: savedData)
    }

    func deleteDevice() throws {
        userDefaults.removeObject(forKey: key)
    }
}
