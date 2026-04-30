import Testing
@testable import SonyRemoteCore

struct RemoteCommandTests {
    @Test func mapsCommandsToIRCCCodes() {
        #expect(RemoteCommand.up.irccCode == "AAAAAQAAAAEAAAB0Aw==")
        #expect(RemoteCommand.down.irccCode == "AAAAAQAAAAEAAAB1Aw==")
        #expect(RemoteCommand.confirm.irccCode == "AAAAAQAAAAEAAABlAw==")
        #expect(RemoteCommand.volumeUp.irccCode == "AAAAAQAAAAEAAAASAw==")
        #expect(RemoteCommand.mute.irccCode == "AAAAAQAAAAEAAAAUAw==")
    }

    @Test func validatesIPv4Address() {
        #expect(SonyDevice.isValidIPv4Address("192.168.1.10"))
        #expect(!SonyDevice.isValidIPv4Address("192.168.1"))
        #expect(!SonyDevice.isValidIPv4Address("192.168.1.999"))
        #expect(!SonyDevice.isValidIPv4Address("tv.local"))
    }
}
