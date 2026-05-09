import Testing
@testable import SonyRemoteCore

struct RemoteCommandTests {
    @Test func mapsCommandsToIRCCCodes() {
        #expect(RemoteCommand.up.irccCode == "AAAAAQAAAAEAAAB0Aw==")
        #expect(RemoteCommand.down.irccCode == "AAAAAQAAAAEAAAB1Aw==")
        #expect(RemoteCommand.confirm.irccCode == "AAAAAQAAAAEAAABlAw==")
        #expect(RemoteCommand.volumeUp.irccCode == "AAAAAQAAAAEAAAASAw==")
        #expect(RemoteCommand.mute.irccCode == "AAAAAQAAAAEAAAAUAw==")
        #expect(RemoteCommand.channelUp.irccCode == "AAAAAQAAAAEAAAAQAw==")
        #expect(RemoteCommand.channelDown.irccCode == "AAAAAQAAAAEAAAARAw==")
        #expect(RemoteCommand.hdmi1.irccCode == "AAAAAgAAABoAAABaAw==")
        #expect(RemoteCommand.num0.irccCode == "AAAAAQAAAAEAAAAJAw==")
        #expect(RemoteCommand.num9.irccCode == "AAAAAQAAAAEAAAAIAw==")
        #expect(RemoteCommand.options.irccCode == "AAAAAgAAAJcAAAA2Aw==")
    }

    @Test func validatesIPv4Address() {
        #expect(SonyDevice.isValidIPv4Address("192.168.1.10"))
        #expect(!SonyDevice.isValidIPv4Address("192.168.1"))
        #expect(!SonyDevice.isValidIPv4Address("192.168.1.999"))
        #expect(!SonyDevice.isValidIPv4Address("tv.local"))
    }
}
