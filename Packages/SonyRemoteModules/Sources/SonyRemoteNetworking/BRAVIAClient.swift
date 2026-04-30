import Foundation
import SonyRemoteCore

public protocol BRAVIAControlling: Sendable {
    func testConnection(device: SonyDevice, psk: String) async throws
    func send(command: RemoteCommand, device: SonyDevice, psk: String) async throws
}

public struct BRAVIAClient: BRAVIAControlling {
    private let transport: HTTPTransport
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(transport: HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func testConnection(device: SonyDevice, psk: String) async throws {
        let request = try makeJSONRPCRequest(
            device: device,
            service: "system",
            psk: psk,
            body: JSONRPCRequest(method: "getPowerStatus", params: [String]())
        )
        let response = try await transport.data(for: request)
        try validate(response)

        let rpcResponse = try decoder.decode(JSONRPCResponse<[PowerStatus]>.self, from: response.data)
        if rpcResponse.error != nil {
            throw mapRPCError(rpcResponse.error)
        }
        guard rpcResponse.result != nil else {
            throw RemoteControlError.invalidResponse
        }
    }

    public func send(command: RemoteCommand, device: SonyDevice, psk: String) async throws {
        let request = try makeIRCCRequest(device: device, psk: psk, irccCode: command.irccCode)
        let response = try await transport.data(for: request)
        try validate(response)
    }
}

public extension BRAVIAClient {
    func makeJSONRPCRequest<T: Encodable>(
        device: SonyDevice,
        service: String,
        psk: String,
        body: T
    ) throws -> URLRequest {
        guard let url = URL(string: "http://\(device.host):\(device.port)/sony/\(service)") else {
            throw RemoteControlError.invalidIPAddress
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue(psk, forHTTPHeaderField: "X-Auth-PSK")
        request.httpBody = try encoder.encode(body)
        return request
    }

    func makeIRCCRequest(device: SonyDevice, psk: String, irccCode: String) throws -> URLRequest {
        guard let url = URL(string: "http://\(device.host):\(device.port)/sony/ircc") else {
            throw RemoteControlError.invalidIPAddress
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("text/xml; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("\"urn:schemas-sony-com:service:IRCC:1#X_SendIRCC\"", forHTTPHeaderField: "SOAPACTION")
        request.setValue(psk, forHTTPHeaderField: "X-Auth-PSK")
        request.httpBody = Self.irccSOAPBody(code: irccCode).data(using: .utf8)
        return request
    }
}

private extension BRAVIAClient {
    static func irccSOAPBody(code: String) -> String {
        """
        <?xml version="1.0"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
            <s:Body>
                <u:X_SendIRCC xmlns:u="urn:schemas-sony-com:service:IRCC:1">
                    <IRCCCode>\(code)</IRCCCode>
                </u:X_SendIRCC>
            </s:Body>
        </s:Envelope>
        """
    }

    func validate(_ response: HTTPResponse) throws {
        switch response.statusCode {
        case 200..<300:
            return
        case 401, 403:
            throw RemoteControlError.unauthorized
        case 404, 405:
            throw RemoteControlError.remoteControlUnavailable
        default:
            throw RemoteControlError.unreachable
        }
    }

    func mapRPCError(_ error: JSONRPCError?) -> RemoteControlError {
        guard let code = error?.code else {
            return .invalidResponse
        }

        switch code {
        case 401:
            return .unauthorized
        case 7:
            return .remoteControlUnavailable
        default:
            return .invalidResponse
        }
    }
}

private struct JSONRPCRequest<Parameters: Encodable>: Encodable {
    let method: String
    let id: Int
    let params: Parameters
    let version: String

    init(method: String, params: Parameters, id: Int = 1, version: String = "1.0") {
        self.method = method
        self.id = id
        self.params = params
        self.version = version
    }
}

private struct JSONRPCResponse<Result: Decodable>: Decodable {
    let result: Result?
    let error: JSONRPCError?
    let id: Int?
}

private struct JSONRPCError: Decodable {
    let code: Int
    let message: String

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.code = try container.decode(Int.self)
        self.message = try container.decode(String.self)
    }
}

private struct PowerStatus: Decodable {
    let status: String
}
