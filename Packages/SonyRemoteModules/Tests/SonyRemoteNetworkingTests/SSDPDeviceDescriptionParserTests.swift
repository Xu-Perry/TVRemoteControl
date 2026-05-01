import Foundation
import Testing
import SonyRemoteCore
@testable import SonyRemoteNetworking

struct SSDPDeviceDescriptionParserTests {
    @Test func parsesBRAVIADeviceDescription() throws {
        let parser = SSDPDeviceDescriptionParser()
        let data = Data("""
        <root>
          <device>
            <friendlyName>BRAVIA XR-65A80L</friendlyName>
            <manufacturer>Sony Corporation</manufacturer>
            <modelName>BRAVIA</modelName>
            <UDN>uuid:sony-bravia-1</UDN>
          </device>
          <X_ScalarWebAPI_ServiceList></X_ScalarWebAPI_ServiceList>
        </root>
        """.utf8)

        let device = try #require(try parser.parse(
            data: data,
            location: URL(string: "http://192.168.1.20:52323/dmr.xml")!
        ))

        #expect(device.displayName == "BRAVIA XR-65A80L")
        #expect(device.host == "192.168.1.20")
        #expect(device.port == 80)
        #expect(device.id == "uuid:sony-bravia-1")
        #expect(device.connectionReadiness == .connectable)
    }

    @Test func usesSonyControlPortAndPreservesCustomFriendlyName() throws {
        let parser = SSDPDeviceDescriptionParser()
        let data = Data("""
        <root>
          <device>
            <friendlyName>S</friendlyName>
            <manufacturer>Sony Corporation</manufacturer>
            <modelName>XR-75X91J</modelName>
            <UDN>uuid:sony-bravia-real</UDN>
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

    @Test func ignoresNonSonyDeviceDescription() throws {
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
        let data = Data("<root><device><manufacturer>Sony</manufacturer></device></root>".utf8)

        #expect(throws: DiscoveryError.malformedDeviceDescription) {
            _ = try parser.parse(data: data, location: URL(string: "file:///tmp/device.xml")!)
        }
    }
}
