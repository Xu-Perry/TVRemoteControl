import Darwin
import Testing
@testable import SonyRemoteNetworking

struct SSDPDiscoveryClientTests {
    @Test func prioritizesWiFiInterfacesForMulticastSearch() {
        let interfaces = [
            IPv4MulticastInterface(name: "utun4", index: 4, address: in_addr(s_addr: 3)),
            IPv4MulticastInterface(name: "en0", index: 1, address: in_addr(s_addr: 1)),
            IPv4MulticastInterface(name: "pdp_ip0", index: 2, address: in_addr(s_addr: 2))
        ]

        let prioritized = SSDPDiscoveryClient.prioritizeMulticastInterfaces(interfaces)

        #expect(prioritized.map(\.name) == ["en0", "pdp_ip0", "utun4"])
    }

    @Test func identifiesLinkLocalIPv4Interfaces() {
        let linkLocal = IPv4MulticastInterface(name: "en2", index: 2, address: in_addr(s_addr: inet_addr("169.254.218.132")))
        let wifi = IPv4MulticastInterface(name: "en0", index: 1, address: in_addr(s_addr: inet_addr("192.168.0.195")))

        #expect(linkLocal.isLinkLocal)
        #expect(!wifi.isLinkLocal)
    }
}
