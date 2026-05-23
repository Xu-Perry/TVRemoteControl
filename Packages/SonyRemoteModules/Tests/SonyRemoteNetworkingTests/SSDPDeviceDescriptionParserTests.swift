import Foundation
import Testing
import SonyRemoteCore
@testable import SonyRemoteNetworking

struct SSDPDeviceDescriptionParserTests {
    @Test func parsesCompatibleDeviceDescription() throws {
        let parser = SSDPDeviceDescriptionParser()
        let data = Data("""
        <root>
          <device>
            <friendlyName>Living Room TV</friendlyName>
            <manufacturer>Example</manufacturer>
            <modelName>TV</modelName>
            <UDN>uuid:living-room-tv</UDN>
          </device>
          <X_ScalarWebAPI_ServiceList></X_ScalarWebAPI_ServiceList>
        </root>
        """.utf8)

        let device = try #require(try parser.parse(
            data: data,
            location: URL(string: "http://192.168.1.20:52323/dmr.xml")!
        ))

        #expect(device.displayName == "Living Room TV")
        #expect(device.host == "192.168.1.20")
        #expect(device.port == 80)
        #expect(device.id == "uuid:living-room-tv")
        #expect(device.connectionReadiness == .connectable)
    }

    @Test func usesControlPortAndPreservesCustomFriendlyName() throws {
        let parser = SSDPDeviceDescriptionParser()
        let data = Data("""
        <root>
          <device>
            <friendlyName>S</friendlyName>
            <manufacturer>Example</manufacturer>
            <modelName>XR-75X91J</modelName>
            <UDN>uuid:compatible-tv-real</UDN>
            <serviceList>
              <service>
                <serviceType>urn:schemas-sony-com:service:ScalarWebAPI:1</serviceType>
                <controlURL>http://192.168.0.196/sony</controlURL>
              </service>
            </serviceList>
          </device>
          <av:X_ScalarWebAPI_DeviceInfo xmlns:av="urn:schemas-sony-com:av"></av:X_ScalarWebAPI_DeviceInfo>
        </root>
        """.utf8)

        let device = try #require(try parser.parse(
            data: data,
            location: URL(string: "http://192.168.0.196:10165/sony/webapi/ssdp/dd.xml")!
        ))

        #expect(device.displayName == "S")
        #expect(device.host == "192.168.0.196")
        #expect(device.port == 80)
    }

    @Test func ignoresIncompatibleDeviceDescription() throws {
        let parser = SSDPDeviceDescriptionParser()
        let data = Data("""
        <root>
          <device>
            <friendlyName>Printer</friendlyName>
            <manufacturer>Example</manufacturer>
          </device>
        </root>
        """.utf8)

        let device = try parser.parse(
            data: data,
            location: URL(string: "http://192.168.1.30/device.xml")!
        )

        #expect(device == nil)
    }

    @Test func throwsForMalformedLocation() throws {
        let parser = SSDPDeviceDescriptionParser()
        let data = Data("<root><device><X_ScalarWebAPI_ServiceList></X_ScalarWebAPI_ServiceList></device></root>".utf8)

        #expect(throws: DiscoveryError.malformedDeviceDescription) {
            _ = try parser.parse(data: data, location: URL(string: "file:///tmp/device.xml")!)
        }
    }
}
