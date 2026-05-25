import Testing
@testable import TVRemoteCore

struct DiscoveredTVDeviceTests {
    @Test func fallsBackToHostWhenNameIsEmpty() {
        let device = DiscoveredTVDevice(name: " ", host: "192.168.1.20")

        #expect(device.displayName == "192.168.1.20")
        #expect(device.id == "192.168.1.20:80")
    }

    @Test func convertsToTVDeviceMetadata() {
        let discovered = DiscoveredTVDevice(
            name: "TV XR-65A80L",
            host: "192.168.1.20",
            port: 52323,
            uniqueIdentifier: "uuid:one"
        )

        let device = discovered.tvDevice(pskKey: "key")

        #expect(device.displayName == "TV XR-65A80L")
        #expect(device.host == "192.168.1.20")
        #expect(device.port == 52323)
        #expect(device.pskKey == "key")
    }
}
