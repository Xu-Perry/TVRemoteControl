import Foundation
import TVRemoteCore

public actor TextFormPublicKeyCache {
    private var keysByDeviceKey: [String: String] = [:]

    public init() {}

    func publicKey(for deviceKey: String) -> String? {
        keysByDeviceKey[deviceKey]
    }

    func store(_ publicKey: String, for deviceKey: String) {
        keysByDeviceKey[deviceKey] = publicKey
    }
}

enum TextFormCacheKey {
    static func make(for device: TVDevice) -> String {
        "\(device.host):\(device.port)"
    }
}
