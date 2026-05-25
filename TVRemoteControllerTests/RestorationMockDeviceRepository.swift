import Foundation
import TVRemoteCore
import TVRemoteNetworking
@testable import TVRemoteController

final class RestorationMockDeviceRepository: DeviceRepository, @unchecked Sendable {
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

    func saveDevice(
        name: String,
        host: String,
        port: Int,
        credential: TVAuthCredential,
        connectionMode: ConnectionMode
    ) throws -> TVDevice {
        let device = TVDevice(name: name, host: host, port: port, pskKey: "key", connectionMode: connectionMode)
        self.device = device
        secretByKey[device.pskKey] = credential.headerValue
        return device
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
        if let device {
            secretByKey.removeValue(forKey: device.pskKey)
        }
        device = nil
    }
}
