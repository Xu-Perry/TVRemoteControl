import Darwin
import Foundation
import Network
import SonyRemoteCore

private func posixError(_ fn: String) -> String {
    "\(fn) failed: \(String(cString: strerror(errno))) (errno \(errno))"
}

struct IPv4MulticastInterface: Sendable {
    let name: String
    let index: UInt32
    let address: in_addr

    var addressDescription: String {
        Self.addressDescription(address)
    }

    var isLinkLocal: Bool {
        let hostOrderAddress = UInt32(bigEndian: address.s_addr)
        return hostOrderAddress & 0xFFFF_0000 == 0xA9FE_0000
    }

    static func addressDescription(_ address: in_addr) -> String {
        var address = address
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
            return "<invalid>"
        }
        return buffer.withUnsafeBufferPointer { pointer in
            guard let baseAddress = pointer.baseAddress else {
                return "<invalid>"
            }
            return String(cString: baseAddress)
        }
    }
}

private final class NetworkSearchState: @unchecked Sendable {
    private let lock = NSLock()
    private var isReady = false
    private var startupErrorDescription: String?
    private var locations = Set<String>()

    func markReady() {
        lock.withLock {
            isReady = true
        }
    }

    func markStartupError(_ error: NWError) {
        lock.withLock {
            startupErrorDescription = String(describing: error)
        }
    }

    func readySnapshot() -> (Bool, String?) {
        lock.withLock {
            (isReady, startupErrorDescription)
        }
    }

    func insertLocation(_ location: String) -> Bool {
        lock.withLock {
            locations.insert(location).inserted
        }
    }

    var locationCount: Int {
        lock.withLock {
            locations.count
        }
    }
}

private final class NetworkSendState: @unchecked Sendable {
    private let lock = NSLock()
    private var errorDescription: String?

    func markCompletion(_ error: NWError?) {
        lock.withLock {
            errorDescription = error.map { String(describing: $0) }
        }
    }

    var completedErrorDescription: String? {
        lock.withLock {
            errorDescription
        }
    }
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
        #if targetEnvironment(simulator)
        try runSocketSearch(timeout: timeout, continuation: continuation)
        return
        #else
        if #available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *) {
            try runNetworkFrameworkSearch(timeout: timeout, continuation: continuation)
            return
        }

        try runSocketSearch(timeout: timeout, continuation: continuation)
        #endif
    }

    @available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
    private func runNetworkFrameworkSearch(
        timeout: TimeInterval,
        continuation: AsyncThrowingStream<SSDPDiscoveryResponse, Error>.Continuation
    ) throws {
        Self.debugLog("Starting Network.framework SSDP search timeout=\(timeout)s")

        guard let multicastAddress = IPv4Address("239.255.255.250") else {
            throw DiscoveryError.networkUnavailable
        }

        let multicastEndpoint = NWEndpoint.hostPort(host: .ipv4(multicastAddress), port: 1900)
        let groupDescriptor = try NWMulticastGroup(for: [multicastEndpoint])
        let parameters = NWParameters.udp
        parameters.requiredInterfaceType = .wifi

        let connectionGroup = NWConnectionGroup(with: groupDescriptor, using: parameters)
        let queue = DispatchQueue(label: "com.perry.braviacontroller.ssdp")
        let readySemaphore = DispatchSemaphore(value: 0)
        let state = NetworkSearchState()

        connectionGroup.stateUpdateHandler = { groupState in
            Self.debugLog("NWConnectionGroup state=\(groupState)")
            switch groupState {
            case .ready:
                state.markReady()
                readySemaphore.signal()
            case let .failed(error), let .waiting(error):
                state.markStartupError(error)
                readySemaphore.signal()
            case .cancelled:
                readySemaphore.signal()
            case .setup:
                break
            @unknown default:
                break
            }
        }

        connectionGroup.setReceiveHandler(maximumMessageSize: 65_535, rejectOversizedMessages: false) { message, content, _ in
            guard let content, !content.isEmpty else {
                Self.debugLog("NWConnectionGroup received empty SSDP packet")
                return
            }
            guard let text = String(data: content, encoding: .utf8) else {
                Self.debugLog("NWConnectionGroup received non-UTF8 SSDP packet bytes=\(content.count)")
                return
            }
            let remote = message.remoteEndpoint?.debugDescription ?? "<unknown>"
            guard let response = Self.parseResponse(text) else {
                let firstLine = text.components(separatedBy: .newlines).first ?? ""
                Self.debugLog("NWConnectionGroup received unparsable packet bytes=\(content.count) from=\(remote) firstLine=\(firstLine)")
                return
            }
            guard state.insertLocation(response.location.absoluteString) else {
                Self.debugLog("NWConnectionGroup ignored duplicate location=\(response.location.absoluteString)")
                return
            }
            Self.debugLog("NWConnectionGroup received SSDP packet bytes=\(content.count) from=\(remote) location=\(response.location.absoluteString)")
            continuation.yield(response)
        }

        connectionGroup.start(queue: queue)
        let didSignalReady = readySemaphore.wait(timeout: .now() + 5) == .success
        let readySnapshot = state.readySnapshot()
        guard didSignalReady, readySnapshot.0 else {
            connectionGroup.cancel()
            if let startError = readySnapshot.1 {
                throw DiscoveryError.unknown("Network.framework SSDP group failed: \(startError)")
            }
            throw DiscoveryError.unknown("Network.framework SSDP group did not become ready.")
        }

        let searchTargets = [
            "urn:schemas-sony-com:service:ScalarWebAPI:1",
            "urn:schemas-upnp-org:device:MediaRenderer:1",
            "ssdp:all"
        ]

        for searchTarget in searchTargets {
            let payload = Self.searchPayload(searchTarget: searchTarget)
            let data = Data(payload.utf8)
            let sendSemaphore = DispatchSemaphore(value: 0)
            let sendState = NetworkSendState()
            connectionGroup.send(content: data, to: multicastEndpoint, message: .default) { error in
                sendState.markCompletion(error)
                sendSemaphore.signal()
            }
            _ = sendSemaphore.wait(timeout: .now() + 3)
            if let sendError = sendState.completedErrorDescription {
                Self.debugLog("NWConnectionGroup send failed st=\(searchTarget): \(sendError)")
                throw DiscoveryError.unknown("Network.framework SSDP send failed: \(sendError)")
            }
            Self.debugLog("NWConnectionGroup send succeeded st=\(searchTarget) bytes=\(data.count)")
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try Task.checkCancellation()
            Thread.sleep(forTimeInterval: 0.2)
        }

        Self.debugLog("Finished Network.framework SSDP receive loop uniqueLocations=\(state.locationCount)")
        connectionGroup.cancel()
    }

    private func runSocketSearch(
        timeout: TimeInterval,
        continuation: AsyncThrowingStream<SSDPDiscoveryResponse, Error>.Continuation
    ) throws {
        Self.debugLog("Starting SSDP search timeout=\(timeout)s")
        let socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFD >= 0 else {
            Self.debugLog("socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP) failed: \(posixError("socket"))")
            throw DiscoveryError.networkUnavailable
        }
        defer { close(socketFD) }
        Self.debugLog("Created UDP socket fd=\(socketFD)")

        var reuse: Int32 = 1
        let reuseResult = setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        Self.debugLog("setsockopt(SO_REUSEADDR) result=\(reuseResult)")

        var receiveTimeout = timeval(tv_sec: 0, tv_usec: 200_000)
        let timeoutResult = setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &receiveTimeout, socklen_t(MemoryLayout<timeval>.size))
        Self.debugLog("setsockopt(SO_RCVTIMEO=200ms) result=\(timeoutResult)")

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
            Self.debugLog("bind(INADDR_ANY:0) failed: \(posixError("bind"))")
            throw DiscoveryError.networkUnavailable
        }
        Self.debugLog("Bound UDP socket to INADDR_ANY:0")

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
        Self.debugLog("Finished SSDP receive loop uniqueLocations=\(receivedLocations.count)")
    }

    private func sendSearchRequests(socketFD: Int32) throws {
        var destination = sockaddr_in()
        destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = UInt16(1900).bigEndian
        destination.sin_addr = in_addr(s_addr: inet_addr("239.255.255.250"))

        var ttl: UInt8 = 2
        let ttlResult = setsockopt(socketFD, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, socklen_t(MemoryLayout<UInt8>.size))
        Self.debugLog("setsockopt(IP_MULTICAST_TTL=2) result=\(ttlResult)")

        let searchTargets = [
            "urn:schemas-sony-com:service:ScalarWebAPI:1",
            "urn:schemas-upnp-org:device:MediaRenderer:1",
            "ssdp:all"
        ]

        #if targetEnvironment(simulator)
        Self.debugLog("Running in simulator; sending SSDP search with default multicast route")
        try sendSearchRequests(socketFD: socketFD, destination: destination, searchTargets: searchTargets, interfaceName: "simulator-default")
        return
        #endif

        let allInterfaces = Self.multicastInterfaces()
        Self.debugLog("Multicast IPv4 interfaces count=\(allInterfaces.count) [\(allInterfaces.map { "\($0.name)#\($0.index)=\($0.addressDescription)" }.joined(separator: ", "))]")
        let interfaces = allInterfaces.filter { !$0.isLinkLocal }
        if interfaces.count != allInterfaces.count {
            Self.debugLog("Skipping link-local multicast interfaces [\(allInterfaces.filter(\.isLinkLocal).map { "\($0.name)#\($0.index)=\($0.addressDescription)" }.joined(separator: ", "))]")
        }
        if interfaces.isEmpty {
            Self.debugLog("No explicit multicast interface found; sending with default route")
            try sendSearchRequests(socketFD: socketFD, destination: destination, searchTargets: searchTargets, interfaceName: "default")
            return
        }

        var sentOnAtLeastOneInterface = false
        var failures: [String] = []
        for interface in interfaces {
            var multicastInterfaceIndex = Int32(interface.index)
            let setInterfaceResult = setsockopt(
                socketFD,
                IPPROTO_IP,
                IP_MULTICAST_IFINDEX,
                &multicastInterfaceIndex,
                socklen_t(MemoryLayout<Int32>.size)
            )

            guard setInterfaceResult == 0 else {
                let failure = "\(interface.name)#\(interface.index)=\(interface.addressDescription): \(posixError("setsockopt(IP_MULTICAST_IFINDEX)"))"
                Self.debugLog("Failed to select multicast interface \(failure)")
                failures.append(failure)
                continue
            }
            Self.debugLog("Selected multicast interface \(interface.name)#\(interface.index)=\(interface.addressDescription)")

            do {
                try sendSearchRequests(socketFD: socketFD, destination: destination, searchTargets: searchTargets, interfaceName: interface.name)
                sentOnAtLeastOneInterface = true
            } catch let error as DiscoveryError {
                let failure = "\(interface.name)#\(interface.index)=\(interface.addressDescription): \(error.localizedDescription)"
                Self.debugLog("Failed sending on multicast interface \(failure)")
                failures.append(failure)
            }
        }

        guard sentOnAtLeastOneInterface else {
            throw DiscoveryError.unknown("Unable to send SSDP multicast search. \(failures.joined(separator: "; "))")
        }
    }

    private func sendSearchRequests(
        socketFD: Int32,
        destination: sockaddr_in,
        searchTargets: [String],
        interfaceName: String
    ) throws {
        var destination = destination
        for searchTarget in searchTargets {
            let payload = Self.searchPayload(searchTarget: searchTarget)
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
                Self.debugLog("sendto failed interface=\(interfaceName) st=\(searchTarget): \(posixError("sendto"))")
                throw DiscoveryError.unknown(posixError("sendto"))
            }
            Self.debugLog("sendto succeeded interface=\(interfaceName) st=\(searchTarget) bytes=\(sent)")
        }
    }

    private static func multicastInterfaces() -> [IPv4MulticastInterface] {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let firstInterface = interfaces else {
            return []
        }
        defer { freeifaddrs(firstInterface) }

        var results: [IPv4MulticastInterface] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstInterface
        while let interface = cursor {
            defer { cursor = interface.pointee.ifa_next }

            guard let address = interface.pointee.ifa_addr,
                  address.pointee.sa_family == sa_family_t(AF_INET) else {
                continue
            }

            let flags = Int32(interface.pointee.ifa_flags)
            guard flags & IFF_UP != 0,
                  flags & IFF_RUNNING != 0,
                  flags & IFF_MULTICAST != 0,
                  flags & IFF_LOOPBACK == 0 else {
                continue
            }

            let interfaceName = String(cString: interface.pointee.ifa_name)
            let interfaceIndex = if_nametoindex(interface.pointee.ifa_name)
            guard interfaceIndex != 0 else {
                continue
            }
            let ipv4Address = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { pointer in
                pointer.pointee.sin_addr
            }

            guard ipv4Address.s_addr != INADDR_ANY else {
                continue
            }

            results.append(IPv4MulticastInterface(name: interfaceName, index: interfaceIndex, address: ipv4Address))
        }
        return prioritizeMulticastInterfaces(results)
    }

    static func prioritizeMulticastInterfaces(_ interfaces: [IPv4MulticastInterface]) -> [IPv4MulticastInterface] {
        interfaces.sorted { lhs, rhs in
            let lhsIsWiFi = lhs.name.hasPrefix("en")
            let rhsIsWiFi = rhs.name.hasPrefix("en")
            if lhsIsWiFi != rhsIsWiFi {
                return lhsIsWiFi
            }
            return lhs.name < rhs.name
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
            let receiveErrno = errno
            if receiveErrno != EAGAIN, receiveErrno != EWOULDBLOCK {
                Self.debugLog("recvfrom returned \(byteCount): \(posixError("recvfrom"))")
            }
            return nil
        }

        let data = Data(buffer.prefix(byteCount))
        guard let text = String(data: data, encoding: .utf8) else {
            Self.debugLog("Received non-UTF8 SSDP packet bytes=\(byteCount)")
            return nil
        }
        let sourceHost = IPv4MulticastInterface.addressDescription(sourceAddress.sin_addr)
        let response = Self.parseResponse(text)
        if let response {
            Self.debugLog("Received SSDP packet bytes=\(byteCount) from=\(sourceHost) location=\(response.location.absoluteString)")
        } else {
            let firstLine = text.components(separatedBy: .newlines).first ?? ""
            Self.debugLog("Received unparsable SSDP packet bytes=\(byteCount) from=\(sourceHost) firstLine=\(firstLine)")
        }
        return response
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

    private static func searchPayload(searchTarget: String) -> String {
        """
        M-SEARCH * HTTP/1.1\r
        HOST: 239.255.255.250:1900\r
        MAN: "ssdp:discover"\r
        MX: 2\r
        ST: \(searchTarget)\r
        \r

        """
    }

    private static func debugLog(_ message: String) {
        #if DEBUG
        print("[SSDPDiscovery] \(message)")
        #endif
    }
}
