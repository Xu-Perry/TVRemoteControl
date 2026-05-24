import Foundation
import SonyRemoteCore

public protocol BRAVIAControlling: Sendable {
    func testConnection(device: SonyDevice, credential: BRAVIAAuthCredential) async throws
    func testCommandAccess(device: SonyDevice, credential: BRAVIAAuthCredential) async throws
    func fetchDeviceName(device: SonyDevice, credential: BRAVIAAuthCredential) async throws
        -> String?
    func send(command: RemoteCommand, device: SonyDevice, credential: BRAVIAAuthCredential)
        async throws
    func sendText(_ text: String, device: SonyDevice, credential: BRAVIAAuthCredential) async throws
}

extension BRAVIAControlling {
    /// Returns the TV's friendly name as set in the TV system settings, or nil.
    /// Default returns nil; override in the real client to fetch from the TV.
    public func fetchDeviceName(device: SonyDevice, credential: BRAVIAAuthCredential) async throws
        -> String?
    {
        nil
    }

    /// Tests whether the IRCC command endpoint accepts the given credential.
    /// Default: no-op. Override in the real client to probe the IRCC endpoint.
    public func testCommandAccess(device: SonyDevice, credential: BRAVIAAuthCredential) async throws
    {}
}

public protocol BRAVIAPairing: Sendable {
    func initiatePairing(device: SonyDevice, clientID: String) async throws -> String
    func confirmPairingPIN(
        device: SonyDevice, registrationID: String, pin: String, clientID: String
    ) async throws -> String
    func cancelPairing(clientID: String) async
}

public struct BRAVIAClient: BRAVIAControlling, BRAVIAPairing {
    private let transport: HTTPTransport
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(transport: HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func testConnection(device: SonyDevice, credential: BRAVIAAuthCredential) async throws {
        // Use getRemoteControllerInfo instead of getPowerStatus because the latter
        // is available without authentication on many compatible TV models, making it
        // impossible to verify the PSK. getRemoteControllerInfo requires auth
        // and returns 401 with an invalid PSK.
        let request = try makeJSONRPCRequest(
            device: device,
            service: "system",
            credential: credential,
            body: JSONRPCRequest(method: "getRemoteControllerInfo", params: [String]())
        )
        let response = try await transport.data(for: request)
        try validate(response)

        // Confirm the response is valid JSON to rule out a mangled response
        // from an incompatible device on the same IP, while still honoring
        // JSON-RPC error payloads that may arrive with HTTP 200.
        _ = try JSONSerialization.jsonObject(with: response.data)
        let rpcResponse = try decoder.decode(JSONRPCErrorEnvelope.self, from: response.data)
        if let error = rpcResponse.error {
            throw mapRPCError(error)
        }
    }

    public func testCommandAccess(device: SonyDevice, credential: BRAVIAAuthCredential) async throws
    {
        // Some TVs allow JSON-RPC access without PSK but require it for IRCC commands.
        // Probe the IRCC endpoint to confirm the credential works for command sending.
        let request = try makeIRCCRequest(device: device, credential: credential, irccCode: "")
        let response = try await transport.data(for: request)
        switch response.statusCode {
        case 401, 403:
            throw RemoteControlError.unauthorized
        default:
            break
        }
    }

    public func fetchDeviceName(device: SonyDevice, credential: BRAVIAAuthCredential) async throws
        -> String?
    {
        if let descriptionName = await fetchDeviceDescriptionName(device: device) {
            return descriptionName
        }

        let request = try makeJSONRPCRequest(
            device: device,
            service: "system",
            credential: credential,
            body: JSONRPCRequest(method: "getSystemInformation", params: [String]())
        )
        let response = try await transport.data(for: request)
        guard response.statusCode == 200 else {
            return nil
        }
        guard let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
            let result = json["result"] as? [Any]
        else {
            return nil
        }
        // The result structure varies: array of arrays or array of objects.
        // Walk through the result to find a dictionary with the "name" key.
        for item in result {
            if let dict = item as? [String: Any],
                let name = usableDeviceName(dict["name"] as? String)
            {
                return name
            }
            if let innerArray = item as? [[String: Any]] {
                for innerDict in innerArray {
                    if let name = usableDeviceName(innerDict["name"] as? String) {
                        return name
                    }
                }
            }
        }
        return nil
    }

    public func send(command: RemoteCommand, device: SonyDevice, credential: BRAVIAAuthCredential)
        async throws
    {
        let request = try makeIRCCRequest(
            device: device, credential: credential, irccCode: command.irccCode)
        let response = try await transport.data(for: request)
        try validate(response)
    }

    public func sendText(_ text: String, device: SonyDevice, credential: BRAVIAAuthCredential)
        async throws
    {
        let request = try makeTextFormRequest(device: device, credential: credential, text: text)
        let response = try await transport.data(for: request)
        try validate(response)

        let rpcResponse = try decoder.decode(
            JSONRPCResponse<[EmptyRPCResult]>.self, from: response.data)
        if rpcResponse.error != nil {
            throw mapRPCError(rpcResponse.error)
        }
        guard rpcResponse.result != nil else {
            throw RemoteControlError.invalidResponse
        }
    }

    // MARK: - BRAVIAPairing

    public func initiatePairing(device: SonyDevice, clientID: String) async throws -> String {
        let params: Any = makePairingInitParams(clientID: clientID, nickname: device.displayName)
        let body = makeJSONRPCBody(method: "actRegister", params: params, id: 1)

        if transport is URLSessionHTTPTransport {
            let request = try makePairingRequest(device: device, body: body)
            let pendingRequest = try await PendingBRAVIAPairingRequest.start(request: request)
            await BRAVIAPairingChallengeRegistry.shared.store(pendingRequest, clientID: clientID)
            return clientID
        }

        let request = try makePairingRequest(device: device, body: body, basicPassword: "0000")
        let response = try await transport.data(for: request)
        if isPairingChallenge(response) {
            return clientID
        }
        try validate(response)

        let rpcResponse = try decoder.decode(
            JSONRPCResponse<[PairingInitResult]>.self, from: response.data)
        if let error = rpcResponse.error {
            throw mapPairingError(error)
        }

        guard rpcResponse.result != nil else {
            throw RemoteControlError.pairingFailed
        }

        return rpcResponse.result?
            .compactMap { $0.extractRegistrationID() }
            .first ?? clientID
    }

    public func confirmPairingPIN(
        device: SonyDevice, registrationID: String, pin: String, clientID: String
    ) async throws -> String {
        if let pendingRequest = await BRAVIAPairingChallengeRegistry.shared.remove(
            clientID: clientID)
        {
            let response = try await pendingRequest.resolve(pin: pin)
            return try processPairingConfirmation(response)
        }

        let params: Any = makePairingConfirmParams(clientID: clientID, nickname: device.displayName)
        let body = makeJSONRPCBody(method: "actRegister", params: params, id: 2)
        let request = try makePairingRequest(device: device, body: body, basicPassword: pin)
        let response = try await transport.data(for: request)
        return try processPairingConfirmation(response)
    }

    public func cancelPairing(clientID: String) async {
        if let pendingRequest = await BRAVIAPairingChallengeRegistry.shared.remove(
            clientID: clientID)
        {
            pendingRequest.cancel()
        }
    }

    private func processPairingConfirmation(_ response: HTTPResponse) throws -> String {
        try validate(response)

        let rpcResponse = try decoder.decode(
            JSONRPCResponse<[BRAVIAPairingResultEntry]>.self, from: response.data)
        if let error = rpcResponse.error {
            throw mapPairingError(error)
        }

        guard let setCookie = response.headers["set-cookie"] else {
            throw RemoteControlError.pairingFailed
        }
        return extractAuthCookie(from: setCookie)
    }
}

// MARK: - Request Building

extension BRAVIAClient {
    public func makeJSONRPCRequest<T: Encodable>(
        device: SonyDevice,
        service: String,
        credential: BRAVIAAuthCredential,
        body: T
    ) throws -> URLRequest {
        guard let url = URL(string: "http://\(device.host):\(device.port)/sony/\(service)") else {
            throw RemoteControlError.invalidIPAddress
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        if !credential.isEmpty {
            request.setValue(credential.headerValue, forHTTPHeaderField: credential.headerName)
        }
        request.httpBody = try encoder.encode(body)
        return request
    }

    public func makeIRCCRequest(
        device: SonyDevice, credential: BRAVIAAuthCredential, irccCode: String
    ) throws -> URLRequest {
        guard let url = URL(string: "http://\(device.host):\(device.port)/sony/ircc") else {
            throw RemoteControlError.invalidIPAddress
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("text/xml; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "\"urn:schemas-sony-com:service:IRCC:1#X_SendIRCC\"", forHTTPHeaderField: "SOAPACTION")
        if !credential.isEmpty {
            request.setValue(credential.headerValue, forHTTPHeaderField: credential.headerName)
        }
        request.httpBody = Self.irccSOAPBody(code: irccCode).data(using: .utf8)
        return request
    }

    public func makeTextFormRequest(
        device: SonyDevice, credential: BRAVIAAuthCredential, text: String
    ) throws -> URLRequest {
        try makeJSONRPCRequest(
            device: device,
            service: "appControl",
            credential: credential,
            body: JSONRPCRequest(method: "setTextForm", params: [text], id: 601)
        )
    }
}

extension BRAVIAClient {
    fileprivate static func irccSOAPBody(code: String) -> String {
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

    fileprivate func validate(_ response: HTTPResponse) throws {
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

    fileprivate func mapRPCError(_ error: JSONRPCError?) -> RemoteControlError {
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

    fileprivate func mapPairingError(_ error: JSONRPCError?) -> RemoteControlError {
        guard let code = error?.code else {
            return .pairingFailed
        }

        switch code {
        case 12:
            return .pairingNotSupported
        case 13:
            return .pairingPinInvalid
        default:
            return .pairingFailed
        }
    }

    fileprivate func extractAuthCookie(from setCookieHeader: String) -> String {
        let pairs = setCookieHeader.components(separatedBy: ";")
        for pair in pairs {
            let trimmed = pair.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("auth=") {
                return trimmed
            }
        }
        return setCookieHeader.components(separatedBy: ";").first?.trimmingCharacters(
            in: .whitespaces) ?? setCookieHeader
    }

    fileprivate func isPairingChallenge(_ response: HTTPResponse) -> Bool {
        guard response.statusCode == 401 || response.statusCode == 403 else {
            return false
        }

        let challenge = response.headers["www-authenticate"]?.lowercased() ?? ""
        return challenge.contains("basic")
    }

    fileprivate func fetchDeviceDescriptionName(device: SonyDevice) async -> String? {
        for url in deviceDescriptionURLs(device: device) {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 2
            guard let response = try? await transport.data(for: request),
                response.statusCode == 200,
                let xml = String(data: response.data, encoding: .utf8),
                let name = friendlyName(in: xml)
            else {
                continue
            }
            return name
        }
        return nil
    }

    fileprivate func deviceDescriptionURLs(device: SonyDevice) -> [URL] {
        [
            URL(string: "http://\(device.host):\(device.port)/sony/webapi/ssdp/dd.xml"),
            URL(string: "http://\(device.host):52323/dmr.xml"),
            URL(string: "http://\(device.host):52323/MediaRenderer.xml"),
        ].compactMap { $0 }
    }

    fileprivate func friendlyName(in xml: String) -> String? {
        guard let openRange = xml.range(of: "<friendlyName>", options: [.caseInsensitive]),
            let closeRange = xml.range(
                of: "</friendlyName>", options: [.caseInsensitive],
                range: openRange.upperBound..<xml.endIndex)
        else {
            return nil
        }

        let rawName = String(xml[openRange.upperBound..<closeRange.lowerBound])
            .replacingOccurrences(of: "<![CDATA[", with: "")
            .replacingOccurrences(of: "]]>", with: "")
        return usableDeviceName(rawName)
    }

    fileprivate func usableDeviceName(_ value: String?) -> String? {
        let name = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else {
            return nil
        }

        let genericNames = ["TV", "TELEVISION"]
        guard !genericNames.contains(name.uppercased()) else {
            return nil
        }
        return name
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

private struct JSONRPCErrorEnvelope: Decodable {
    let error: JSONRPCError?
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

private struct PairingInitResult: Decodable {
    let client: String?
    let id: Int?
    let results: [[String: String]]?

    func extractRegistrationID() -> String? {
        if let results {
            for entry in results {
                if let regID = entry["RegistrationId"] ?? entry["registrationId"]
                    ?? entry["registerid"]
                {
                    return regID
                }
            }
        }
        return nil
    }
}

private struct BRAVIAPairingResultEntry: Decodable {}
private struct EmptyRPCResult: Decodable {}

private func makePairingRequest(device: SonyDevice, body: Data) throws -> URLRequest {
    guard let url = URL(string: "http://\(device.host):\(device.port)/sony/accessControl") else {
        throw RemoteControlError.invalidIPAddress
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 60
    request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    return request
}

private func makePairingRequest(device: SonyDevice, body: Data, basicPassword: String) throws
    -> URLRequest
{
    guard let url = URL(string: "http://\(device.host):\(device.port)/sony/accessControl") else {
        throw RemoteControlError.invalidIPAddress
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 10
    request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
    request.setValue(
        basicAuthorizationHeader(password: basicPassword), forHTTPHeaderField: "Authorization")
    request.httpBody = body
    return request
}

private func makeJSONRPCBody(method: String, params: Any, id: Int, version: String = "1.0") -> Data
{
    let dict: [String: Any] = [
        "method": method,
        "params": params,
        "id": id,
        "version": version,
    ]
    return try! JSONSerialization.data(withJSONObject: dict)
}

private func makePairingInitParams(clientID: String, nickname: String) -> Any {
    let clientInfo: [String: String] = [
        "clientid": clientID, "nickname": nickname, "level": "private",
    ]
    let wolSettings: [[String: String]] = [["value": "yes", "function": "WOL"]]
    return [clientInfo, wolSettings] as [Any]
}

private func makePairingConfirmParams(clientID: String, nickname: String) -> Any {
    let clientInfo: [String: String] = [
        "clientid": clientID, "nickname": nickname, "level": "private",
    ]
    let pinAndWol: [[String: String]] = [
        ["value": "yes", "function": "WOL"]
    ]
    return [clientInfo, pinAndWol] as [Any]
}

private func basicAuthorizationHeader(password: String) -> String {
    let rawValue = ":\(password)"
    let encoded = Data(rawValue.utf8).base64EncodedString()
    return "Basic \(encoded)"
}

private actor BRAVIAPairingChallengeRegistry {
    static let shared = BRAVIAPairingChallengeRegistry()

    private var requestsByClientID: [String: PendingBRAVIAPairingRequest] = [:]

    func store(_ request: PendingBRAVIAPairingRequest, clientID: String) {
        requestsByClientID[clientID]?.cancel()
        requestsByClientID[clientID] = request
    }

    func remove(clientID: String) -> PendingBRAVIAPairingRequest? {
        requestsByClientID.removeValue(forKey: clientID)
    }
}

private final class PendingBRAVIAPairingRequest: NSObject, URLSessionDataDelegate,
    @unchecked Sendable
{
    private let queue = DispatchQueue(label: "TVRemote.PendingPairingRequest")
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var response: HTTPURLResponse?
    private var data = Data()
    private var challengeHandler: ((URLSession.AuthChallengeDisposition, URLCredential?) -> Void)?
    private var challengeContinuation: CheckedContinuation<Void, Error>?
    private var responseContinuation: CheckedContinuation<HTTPResponse, Error>?
    private var completedResult: Result<HTTPResponse, Error>?
    private var didReceiveChallenge = false

    static func start(request: URLRequest) async throws -> PendingBRAVIAPairingRequest {
        let pendingRequest = PendingBRAVIAPairingRequest()
        pendingRequest.start(request: request)
        do {
            try await pendingRequest.waitForChallenge()
            return pendingRequest
        } catch {
            pendingRequest.cancel()
            throw error
        }
    }

    func resolve(pin: String) async throws -> HTTPResponse {
        queue.sync {
            let credential = URLCredential(user: "", password: pin, persistence: .forSession)
            challengeHandler?(.useCredential, credential)
            challengeHandler = nil
        }
        return try await waitForResponse()
    }

    func cancel() {
        queue.sync {
            challengeHandler?(.cancelAuthenticationChallenge, nil)
            challengeHandler = nil
            task?.cancel()
            session?.invalidateAndCancel()
            challengeContinuation?.resume(throwing: CancellationError())
            challengeContinuation = nil
            responseContinuation?.resume(throwing: CancellationError())
            responseContinuation = nil
        }
    }

    private func start(request: URLRequest) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)
        queue.sync {
            self.session = session
            self.task = task
        }
        task.resume()
    }

    private func waitForChallenge() async throws {
        try await withTimeout(seconds: 10) {
            try await withCheckedThrowingContinuation { continuation in
                self.queue.async {
                    if self.didReceiveChallenge {
                        continuation.resume()
                    } else if let completedResult = self.completedResult {
                        continuation.resume(with: completedResult.map { _ in () })
                    } else {
                        self.challengeContinuation = continuation
                    }
                }
            }
        }
    }

    private func waitForResponse() async throws -> HTTPResponse {
        try await withTimeout(seconds: 60) {
            try await withCheckedThrowingContinuation { continuation in
                self.queue.async {
                    if let completedResult = self.completedResult {
                        continuation.resume(with: completedResult)
                    } else {
                        self.responseContinuation = continuation
                    }
                }
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler:
            @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        queue.async {
            self.didReceiveChallenge = true
            self.challengeHandler = completionHandler
            self.challengeContinuation?.resume()
            self.challengeContinuation = nil
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        queue.async {
            self.response = response as? HTTPURLResponse
            completionHandler(.allow)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        queue.async {
            self.data.append(data)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    {
        queue.async {
            let result: Result<HTTPResponse, Error>
            if let error {
                result = .failure(error)
            } else if let response = self.response {
                let headers = response.allHeaderFields.reduce(into: [String: String]()) {
                    result, pair in
                    if let key = pair.key as? String, let value = pair.value as? String {
                        result[key.lowercased()] = value
                    }
                }
                result = .success(
                    HTTPResponse(data: self.data, statusCode: response.statusCode, headers: headers)
                )
            } else {
                result = .failure(RemoteControlError.invalidResponse)
            }

            self.completedResult = result
            self.challengeContinuation?.resume(with: result.map { _ in () })
            self.challengeContinuation = nil
            self.responseContinuation?.resume(with: result)
            self.responseContinuation = nil
            self.session?.finishTasksAndInvalidate()
            self.session = nil
        }
    }
}

private func withTimeout<T: Sendable>(
    seconds: UInt64, operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            throw RemoteControlError.pairingTimedOut
        }

        guard let value = try await group.next() else {
            throw RemoteControlError.pairingTimedOut
        }
        group.cancelAll()
        return value
    }
}
