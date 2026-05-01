import Testing
@testable import SonyRemoteCore

struct DiscoveredBRAVIADeviceTests {
    @Test func fallsBackToHostWhenNameIsEmpty() {
        let device = DiscoveredBRAVIADevice(name: " ", host: "192.168.1.20")

        #expect(device.displayName == "192.168.1.20")
        #expect(device.id == "192.168.1.20:80")
    }

    @Test func convertsToSonyDeviceMetadata() {
        let discovered = DiscoveredBRAVIADevice(
            name: "BRAVIA XR-65A80L",
            host: "192.168.1.20",
            port: 52323,
            uniqueIdentifier: "uuid:one"
        )

        let device = discovered.sonyDevice(pskKey: "key")

        #expect(device.displayName == "BRAVIA XR-65A80L")
        #expect(device.host == "192.168.1.20")
        #expect(device.port == 52323)
        #expect(device.pskKey == "key")
    }
}
