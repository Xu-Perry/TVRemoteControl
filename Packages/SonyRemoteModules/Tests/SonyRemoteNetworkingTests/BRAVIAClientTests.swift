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
            credential: .psk("1234"),
            body: TestBody(method: "getRemoteControllerInfo")
        )

        #expect(request.url?.absoluteString == "http://192.168.1.2:80/sony/system")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "X-Auth-PSK") == "1234")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json; charset=UTF-8")
        let body = try #require(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        #expect(body.contains("getRemoteControllerInfo"))
    }

    @Test func buildsIRCCRequest() throws {
        let client = BRAVIAClient(transport: MockTransport())
        let device = SonyDevice(name: "Living Room", host: "192.168.1.2", pskKey: "key")

        let request = try client.makeIRCCRequest(device: device, credential: .psk("1234"), irccCode: RemoteCommand.confirm.irccCode)

        #expect(request.url?.absoluteString == "http://192.168.1.2:80/sony/ircc")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "SOAPACTION") == "\"urn:schemas-sony-com:service:IRCC:1#X_SendIRCC\"")
        let body = try #require(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        #expect(body.contains(RemoteCommand.confirm.irccCode))
    }

    @Test func buildsTextFormRequest() throws {
        let client = BRAVIAClient(transport: MockTransport())
        let device = SonyDevice(name: "Living Room", host: "192.168.1.2", pskKey: "key")

        let request = try client.makeTextFormRequest(device: device, credential: .psk("1234"), text: "hello world")

        #expect(request.url?.absoluteString == "http://192.168.1.2:80/sony/appControl")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "X-Auth-PSK") == "1234")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json; charset=UTF-8")
        let body = try #require(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        #expect(body.contains("\"method\":\"setTextForm\""))
        #expect(body.contains("\"params\":[\"hello world\"]"))
    }

    @Test func sendTextUsesAppControlTextFormAPI() async throws {
        let transport = MockTransport(response: HTTPResponse(
            data: Data("{\"result\":[],\"id\":601}".utf8),
            statusCode: 200
        ))
        let client = BRAVIAClient(transport: transport)
        let device = SonyDevice(name: "Living Room", host: "192.168.1.2", pskKey: "key")

        try await client.sendText("hello world", device: device, credential: .psk("1234"))

        let request = try #require(transport.requests.first)
        #expect(request.url?.absoluteString == "http://192.168.1.2:80/sony/appControl")
    }

    @Test func fetchDeviceNameIgnoresGenericTVName() async throws {
        let transport = MockTransport(responses: [
            HTTPResponse(data: Data(), statusCode: 404),
            HTTPResponse(data: Data(), statusCode: 404),
            HTTPResponse(data: Data(), statusCode: 404),
            HTTPResponse(data: Data("{\"result\":[{\"name\":\"TV\"}],\"id\":33}".utf8), statusCode: 200)
        ])
        let client = BRAVIAClient(transport: transport)
        let device = SonyDevice(name: "192.168.1.2", host: "192.168.1.2", pskKey: "key")

        let name = try await client.fetchDeviceName(device: device, credential: .psk("1234"))

        #expect(name == nil)
    }

    @Test func fetchDeviceNameUsesDeviceDescriptionFriendlyName() async throws {
        let transport = MockTransport(responses: [
            HTTPResponse(data: Data("""
            <root>
                <device>
                    <friendlyName>Living Room TV</friendlyName>
                </device>
            </root>
            """.utf8), statusCode: 200)
        ])
        let client = BRAVIAClient(transport: transport)
        let device = SonyDevice(name: "192.168.1.2", host: "192.168.1.2", pskKey: "key")

        let name = try await client.fetchDeviceName(device: device, credential: .psk("1234"))

        #expect(name == "Living Room TV")
        #expect(transport.requests.first?.url?.absoluteString == "http://192.168.1.2:80/sony/webapi/ssdp/dd.xml")
    }

    @Test func mapsUnauthorizedStatus() async {
        let client = BRAVIAClient(transport: MockTransport(response: HTTPResponse(data: Data(), statusCode: 401)))
        let device = SonyDevice(name: "Living Room", host: "192.168.1.2", pskKey: "key")

        await #expect(throws: RemoteControlError.unauthorized) {
            try await client.send(command: .home, device: device, credential: .psk("bad"))
        }
    }

    @Test func testConnectionMapsJSONRPCErrorBody() async {
        let transport = MockTransport(response: HTTPResponse(
            data: Data("{\"error\":[401,\"Unauthorized\"],\"id\":1}".utf8),
            statusCode: 200
        ))
        let client = BRAVIAClient(transport: transport)
        let device = SonyDevice(name: "Living Room", host: "192.168.1.2", pskKey: "key")

        await #expect(throws: RemoteControlError.unauthorized) {
            try await client.testConnection(device: device, credential: .psk("bad"))
        }
    }

    @Test func buildsJSONRPCRequestWithCookieCredential() throws {
        let client = BRAVIAClient(transport: MockTransport())
        let device = SonyDevice(name: "Living Room", host: "192.168.1.2", pskKey: "key")

        let request = try client.makeJSONRPCRequest(
            device: device,
            service: "system",
            credential: .cookie("auth=sample-cookie"),
            body: TestBody(method: "getRemoteControllerInfo")
        )

        #expect(request.value(forHTTPHeaderField: "Cookie") == "auth=sample-cookie")
        #expect(request.value(forHTTPHeaderField: "X-Auth-PSK") == nil)
    }

    @Test func pairingRequestHasCorrectJSONRPCStructure() throws {
        let client = BRAVIAClient(transport: MockTransport())
        let device = SonyDevice(name: "Living Room", host: "192.168.1.2", pskKey: "key")

        let request = try client.makeJSONRPCRequest(
            device: device,
            service: "accessControl",
            credential: .psk(""),
            body: TestBody(method: "actRegister")
        )

        #expect(request.url?.absoluteString == "http://192.168.1.2:80/sony/accessControl")
        #expect(request.httpMethod == "POST")
        let body = try #require(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        #expect(body.contains("actRegister"))
    }

    @Test func extractAuthCookieFromSetCookieHeader() async throws {
        let authCookie = "auth=abc123; Path=/; HttpOnly"
        let transport = MockTransport(response: HTTPResponse(
            data: Data("{\"result\":[{\"key\":\"val\"}],\"id\":1}".utf8),
            statusCode: 200,
            headers: ["set-cookie": authCookie]
        ))
        let client = BRAVIAClient(transport: transport)
        let device = SonyDevice(name: "TV", host: "192.168.1.2", pskKey: "key")

        let cookie = try await client.confirmPairingPIN(
            device: device,
            registrationID: "reg-1",
            pin: "1234",
            clientID: "test:uuid"
        )

        #expect(cookie == "auth=abc123")
        let request = try #require(transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Basic OjEyMzQ=")
    }

    @Test func initiatePairingAcceptsSuccessfulResponseWithoutRegistrationID() async throws {
        let transport = MockTransport(response: HTTPResponse(
            data: Data("{\"result\":[{}],\"id\":1}".utf8),
            statusCode: 200
        ))
        let client = BRAVIAClient(transport: transport)
        let device = SonyDevice(name: "TV", host: "192.168.1.2", pskKey: "key")

        let registrationID = try await client.initiatePairing(device: device, clientID: "test:uuid")

        #expect(registrationID == "test:uuid")
    }

    @Test func initiatePairingTreatsBasicChallengeAsPendingPINEntry() async throws {
        let transport = MockTransport(response: HTTPResponse(
            data: Data("{\"error\":[401,\"Unauthorized\"],\"id\":1}".utf8),
            statusCode: 401,
            headers: ["www-authenticate": "Basic realm=\"Private Page\""]
        ))
        let client = BRAVIAClient(transport: transport)
        let device = SonyDevice(name: "TV", host: "192.168.1.2", pskKey: "key")

        let registrationID = try await client.initiatePairing(device: device, clientID: "test:uuid")

        #expect(registrationID == "test:uuid")
        let request = try #require(transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Basic OjAwMDA=")
        let body = try #require(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        #expect(body.contains("\"level\":\"private\""))
    }
}

private struct TestBody: Encodable {
    let method: String
}

private final class MockTransport: HTTPTransport, @unchecked Sendable {
    private let response: HTTPResponse
    private var responses: [HTTPResponse]
    private(set) var requests: [URLRequest] = []

    init(response: HTTPResponse = HTTPResponse(data: Data(), statusCode: 200)) {
        self.response = response
        self.responses = []
    }

    init(responses: [HTTPResponse]) {
        self.response = HTTPResponse(data: Data(), statusCode: 200)
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        if !responses.isEmpty {
            return responses.removeFirst()
        }
        return response
    }
}
