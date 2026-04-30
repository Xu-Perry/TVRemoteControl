import Foundation
import SonyRemoteCore

protocol DeviceMetadataStore: Sendable {
    func loadDevice() throws -> SonyDevice?
    func saveDevice(_ device: SonyDevice) throws
    func deleteDevice() throws
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
