import Foundation
import Testing
import SonyRemoteCore
@testable import SonyRemoteNetworking

struct BRAVIAClientTests {
    @Test func buildsJSONRPCConnectionRequest() throws {
        let client = BRAVIAClient(transport: MockTransport())
        let device = SonyDevice(name: "Living Room", host: "192.168.1.2", pskKey: "key")

        let request = try client.makeJSONRPCRequest(
            device: device,
            service: "system",
            psk: "1234",
            body: TestBody(method: "getPowerStatus")
        )

        #expect(request.url?.absoluteString == "http://192.168.1.2:80/sony/system")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "X-Auth-PSK") == "1234")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json; charset=UTF-8")
        let body = try #require(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        #expect(body.contains("getPowerStatus"))
    }

    @Test func buildsIRCCRequest() throws {
        let client = BRAVIAClient(transport: MockTransport())
        let device = SonyDevice(name: "Living Room", host: "192.168.1.2", pskKey: "key")

        let request = try client.makeIRCCRequest(device: device, psk: "1234", irccCode: RemoteCommand.confirm.irccCode)

        #expect(request.url?.absoluteString == "http://192.168.1.2:80/sony/ircc")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "SOAPACTION") == "\"urn:schemas-sony-com:service:IRCC:1#X_SendIRCC\"")
        let body = try #require(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        #expect(body.contains(RemoteCommand.confirm.irccCode))
    }

    @Test func mapsUnauthorizedStatus() async {
        let client = BRAVIAClient(transport: MockTransport(response: HTTPResponse(data: Data(), statusCode: 401)))
        let device = SonyDevice(name: "Living Room", host: "192.168.1.2", pskKey: "key")

        await #expect(throws: RemoteControlError.unauthorized) {
            try await client.send(command: .home, device: device, psk: "bad")
        }
    }
}

private struct TestBody: Encodable {
    let method: String
}

private struct MockTransport: HTTPTransport {
    let response: HTTPResponse

    init(response: HTTPResponse = HTTPResponse(data: Data(), statusCode: 200)) {
        self.response = response
    }

    func data(for request: URLRequest) async throws -> HTTPResponse {
        response
    }
}
