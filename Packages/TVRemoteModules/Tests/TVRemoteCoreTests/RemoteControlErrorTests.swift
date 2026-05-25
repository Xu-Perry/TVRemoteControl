import Testing
@testable import TVRemoteCore

struct RemoteControlErrorTests {
    @Test func discoveryErrorsExposeLocalizedDescriptions() {
        #expect(DiscoveryError.networkUnavailable.localizedDescription == "Local network discovery is unavailable. Check Wi-Fi, local network permission, and multicast entitlement.")
        #expect(DiscoveryError.unknown("SSDP send failed").localizedDescription == "SSDP send failed")
    }

    @Test func mapsDiscoveryErrorsToRemoteControlErrors() {
        #expect(RemoteControlError.map(DiscoveryError.networkUnavailable) == .unreachable)
        #expect(RemoteControlError.map(DiscoveryError.noDevices) == .missingDevice)
        #expect(RemoteControlError.map(DiscoveryError.malformedDeviceDescription) == .invalidResponse)
        #expect(RemoteControlError.map(DiscoveryError.unknown("SSDP send failed")) == .unknown("SSDP send failed"))
    }
}
