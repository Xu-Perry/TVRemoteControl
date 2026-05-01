import Darwin
import Foundation
import SonyRemoteCore

private func posixError(_ fn: String) -> String {
    String(cString: strerror(errno))
}

public struct SSDPDiscoveryResponse: Equatable, Sendable {
    public let location: URL
    public let headers: [String: String]

    public init(location: URL, headers: [String: String] = [:]) {
        self.location = location
        self.headers = headers
    }
}

public protocol SSDPDiscoveryClientProtocol: Sendable {
    func search(timeout: TimeInterval) -> AsyncThrowingStream<SSDPDiscoveryResponse, Error>
}

public struct SSDPDiscoveryClient: SSDPDiscoveryClientProtocol {
    public init() {}

    public func search(timeout: TimeInterval = 8) -> AsyncThrowingStream<SSDPDiscoveryResponse, Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached {
                do {
                    try runSearch(timeout: timeout, continuation: continuation)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: DiscoveryError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func runSearch(
        timeout: TimeInterval,
        continuation: AsyncThrowingStream<SSDPDiscoveryResponse, Error>.Continuation
    ) throws {
        let socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFD >= 0 else {
            throw DiscoveryError.networkUnavailable
        }
        defer { close(socketFD) }

        var reuse: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var receiveTimeout = timeval(tv_sec: 0, tv_usec: 200_000)
        setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &receiveTimeout, socklen_t(MemoryLayout<timeval>.size))

        var localAddress = sockaddr_in()
        localAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        localAddress.sin_family = sa_family_t(AF_INET)
        localAddress.sin_port = 0
        localAddress.sin_addr = in_addr(s_addr: INADDR_ANY)

        let bindResult = withUnsafePointer(to: &localAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.bind(socketFD, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw DiscoveryError.networkUnavailable
        }

        let deadline = Date().addingTimeInterval(timeout)
        try sendSearchRequests(socketFD: socketFD)

        var receivedLocations = Set<String>()
        while Date() < deadline {
            try Task.checkCancellation()
            if let response = receiveResponse(socketFD: socketFD),
               receivedLocations.insert(response.location.absoluteString).inserted {
                continuation.yield(response)
            }
        }
    }

    private func sendSearchRequests(socketFD: Int32) throws {
        var destination = sockaddr_in()
        destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = UInt16(1900).bigEndian
        destination.sin_addr = in_addr(s_addr: inet_addr("239.255.255.250"))

        let searchTargets = [
            "urn:schemas-sony-com:service:ScalarWebAPI:1",
            "urn:schemas-upnp-org:device:MediaRenderer:1",
            "ssdp:all"
        ]

        for searchTarget in searchTargets {
            let payload = """
            M-SEARCH * HTTP/1.1\r
            HOST: 239.255.255.250:1900\r
            MAN: "ssdp:discover"\r
            MX: 2\r
            ST: \(searchTarget)\r
            \r

            """
            let bytes = Array(payload.utf8)
            let sent = bytes.withUnsafeBytes { buffer in
                withUnsafePointer(to: &destination) { pointer in
                    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                        sendto(
                            socketFD,
                            buffer.baseAddress,
                            buffer.count,
                            0,
                            sockaddrPointer,
                            socklen_t(MemoryLayout<sockaddr_in>.size)
                        )
                    }
                }
            }

            guard sent >= 0 else {
                throw DiscoveryError.unknown(posixError("sendto"))
            }
        }
    }

    private func receiveResponse(socketFD: Int32) -> SSDPDiscoveryResponse? {
        var buffer = [UInt8](repeating: 0, count: 65_535)
        var sourceAddress = sockaddr_in()
        var sourceLength = socklen_t(MemoryLayout<sockaddr_in>.size)

        let byteCount = buffer.withUnsafeMutableBytes { rawBuffer in
            withUnsafeMutablePointer(to: &sourceAddress) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                    recvfrom(
                        socketFD,
                        rawBuffer.baseAddress,
                        rawBuffer.count,
                        0,
                        sockaddrPointer,
                        &sourceLength
                    )
                }
            }
        }

        guard byteCount > 0 else {
            return nil
        }

        let data = Data(buffer.prefix(byteCount))
        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return Self.parseResponse(text)
    }

    static func parseResponse(_ text: String) -> SSDPDiscoveryResponse? {
        var headers: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            guard let separator = line.firstIndex(of: ":") else {
                continue
            }
            let key = String(line[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            headers[key] = value
        }

        guard let locationValue = headers["location"], let location = URL(string: locationValue) else {
            return nil
        }

        return SSDPDiscoveryResponse(location: location, headers: headers)
    }
}
