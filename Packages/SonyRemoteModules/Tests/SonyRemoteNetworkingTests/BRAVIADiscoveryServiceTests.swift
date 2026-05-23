import Foundation
import Testing
import SonyRemoteCore
@testable import SonyRemoteNetworking

struct BRAVIADiscoveryServiceTests {
    @Test func filtersAndDeduplicatesCompatibleDevices() async throws {
        let client = MockSSDPClient(responses: [
            SSDPDiscoveryResponse(location: URL(string: "http://192.168.1.20:80/a.xml")!),
            SSDPDiscoveryResponse(location: URL(string: "http://192.168.1.20:80/b.xml")!),
            SSDPDiscoveryResponse(location: URL(string: "http://192.168.1.30:80/printer.xml")!)
        ])
        let service = BRAVIADiscoveryService(ssdpClient: client) { url in
            if url.absoluteString.contains("printer") {
                return Data("<root><device><manufacturer>Example</manufacturer></device></root>".utf8)
            }
            return Data("""
            <root>
              <device>
                <friendlyName>Living Room TV</friendlyName>
                <manufacturer>Example</manufacturer>
                <UDN>uuid:one</UDN>
              </device>
              <X_ScalarWebAPI_ServiceList></X_ScalarWebAPI_ServiceList>
            </root>
            """.utf8)
        }

        var finishedDevices: [DiscoveredBRAVIADevice] = []
        for try await event in service.discover(timeout: 1) {
            if case let .finished(devices) = event {
                finishedDevices = devices
            }
        }

        #expect(finishedDevices.count == 1)
        #expect(finishedDevices.first?.displayName == "Living Room TV")
    }

    @Test func emptySearchFinishesWithNoDevices() async throws {
        let client = MockSSDPClient(responses: [])
        let service = BRAVIADiscoveryService(ssdpClient: client) { _ in Data() }

        var finishedDevices: [DiscoveredBRAVIADevice]?
        for try await event in service.discover(timeout: 1) {
            if case let .finished(devices) = event {
                finishedDevices = devices
            }
        }

        #expect(finishedDevices == [])
    }

    @Test func ignoresDescriptionFetchFailuresAndContinuesDiscovery() async throws {
        let client = MockSSDPClient(responses: [
            SSDPDiscoveryResponse(location: URL(string: "http://192.168.1.30/missing.xml")!),
            SSDPDiscoveryResponse(location: URL(string: "http://192.168.1.20/dd.xml")!)
        ])
        let service = BRAVIADiscoveryService(ssdpClient: client) { url in
            if url.absoluteString.contains("missing") {
                throw URLError(.cannotConnectToHost)
            }
            return Data("""
            <root>
              <device>
                <friendlyName>Living Room TV</friendlyName>
                <manufacturer>Example</manufacturer>
                <UDN>uuid:one</UDN>
              </device>
              <X_ScalarWebAPI_ServiceList></X_ScalarWebAPI_ServiceList>
            </root>
            """.utf8)
        }

        var finishedDevices: [DiscoveredBRAVIADevice] = []
        for try await event in service.discover(timeout: 1) {
            if case let .finished(devices) = event {
                finishedDevices = devices
            }
        }

        #expect(finishedDevices.count == 1)
        #expect(finishedDevices.first?.displayName == "Living Room TV")
    }
}

private struct MockSSDPClient: SSDPDiscoveryClientProtocol {
    let responses: [SSDPDiscoveryResponse]

    func search(timeout: TimeInterval) -> AsyncThrowingStream<SSDPDiscoveryResponse, Error> {
        AsyncThrowingStream { continuation in
            for response in responses {
                continuation.yield(response)
            }
            continuation.finish()
        }
    }
}
