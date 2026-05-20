import Foundation
import SonyRemoteCore

protocol DeviceMetadataStore: Sendable {
    func loadDevice() throws -> SonyDevice?
    func saveDevice(_ device: SonyDevice) throws
    func deleteDevice() throws
}

struct KeychainDeviceMetadataStore: DeviceMetadataStore {
    private let secretStore: SecretStore
    private let key: String
    private let legacyStore: DeviceMetadataStore?

    init(
        secretStore: SecretStore = KeychainSecretStore(service: "com.perry.SonyRemoteController.device"),
        key: String = "saved.bravia.device",
        legacyStore: DeviceMetadataStore? = UserDefaultsDeviceMetadataStore()
    ) {
        self.secretStore = secretStore
        self.key = key
        self.legacyStore = legacyStore
    }

    func loadDevice() throws -> SonyDevice? {
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

    func saveDevice(_ device: SonyDevice) throws {
        let data = try JSONEncoder().encode(device)
        try secretStore.save(data.base64EncodedString(), for: key)
        try? legacyStore?.deleteDevice()
    }

    func deleteDevice() throws {
        try secretStore.delete(for: key)
        try legacyStore?.deleteDevice()
    }

    private func decodeDevice(from value: String) throws -> SonyDevice {
        guard let data = Data(base64Encoded: value) else {
            throw RemoteControlError.keychainFailure("Unable to read the saved BRAVIA TV settings.")
        }

        do {
            return try JSONDecoder().decode(SonyDevice.self, from: data)
        } catch {
            throw RemoteControlError.keychainFailure("Unable to decode the saved BRAVIA TV settings.")
        }
    }
}

struct UserDefaultsDeviceMetadataStore: DeviceMetadataStore {
    private let userDefaults: UserDefaults
    private let key: String

    init(userDefaults: UserDefaults = .standard, key: String = "saved.bravia.device") {
        self.userDefaults = userDefaults
        self.key = key
    }

    func loadDevice() throws -> SonyDevice? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        return try JSONDecoder().decode(SonyDevice.self, from: data)
    }

    func saveDevice(_ device: SonyDevice) throws {
        let data = try JSONEncoder().encode(device)
        userDefaults.set(data, forKey: key)
        userDefaults.synchronize()

        guard let savedData = userDefaults.data(forKey: key) else {
            throw RemoteControlError.keychainFailure("Unable to save the BRAVIA TV settings.")
        }

        _ = try JSONDecoder().decode(SonyDevice.self, from: savedData)
    }

    func deleteDevice() throws {
        userDefaults.removeObject(forKey: key)
    }
}
