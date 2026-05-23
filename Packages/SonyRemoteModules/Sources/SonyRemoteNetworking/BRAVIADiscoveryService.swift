import Foundation
import SonyRemoteCore

public enum BRAVIADiscoveryEvent: Equatable, Sendable {
    case deviceFound(DiscoveredBRAVIADevice)
    case finished([DiscoveredBRAVIADevice])
}

public protocol BRAVIADiscoveryServicing: Sendable {
    func discover(timeout: TimeInterval) -> AsyncThrowingStream<BRAVIADiscoveryEvent, Error>
}

public struct BRAVIADiscoveryService: BRAVIADiscoveryServicing {
    private let ssdpClient: SSDPDiscoveryClientProtocol
    private let parser: SSDPDeviceDescriptionParser
    private let fetchDescription: @Sendable (URL) async throws -> Data

    public init(
        ssdpClient: SSDPDiscoveryClientProtocol = SSDPDiscoveryClient(),
        parser: SSDPDeviceDescriptionParser = SSDPDeviceDescriptionParser(),
        fetchDescription: @escaping @Sendable (URL) async throws -> Data = { url in
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        }
    ) {
        self.ssdpClient = ssdpClient
        self.parser = parser
        self.fetchDescription = fetchDescription
    }

    public func discover(timeout: TimeInterval = 5) -> AsyncThrowingStream<BRAVIADiscoveryEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var devicesByID: [String: DiscoveredBRAVIADevice] = [:]
                do {
                    for try await response in ssdpClient.search(timeout: timeout) {
                        try Task.checkCancellation()
                        Self.debugLog("SSDP response location=\(response.location.absoluteString)")
                        guard let device = await device(from: response) else {
                            continue
                        }
                        let existing = devicesByID[device.id]
                        if existing == nil || existing?.lastSeenAt ?? .distantPast < device.lastSeenAt {
                            devicesByID[device.id] = device
                            continuation.yield(.deviceFound(device))
                        }
                    }

                    let devices = devicesByID.values.sorted { $0.displayName < $1.displayName }
                    continuation.yield(.finished(devices))
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

    private func device(from response: SSDPDiscoveryResponse) async -> DiscoveredBRAVIADevice? {
        do {
            let data = try await fetchDescription(response.location)
            let device = try parser.parse(data: data, location: response.location)
            if let device {
                Self.debugLog("Parsed TV name=\(device.displayName) host=\(device.host) port=\(device.port)")
            } else {
                Self.debugLog("Ignored incompatible description location=\(response.location.absoluteString)")
            }
            return device
        } catch {
            Self.debugLog("Failed description location=\(response.location.absoluteString) error=\(error)")
            return nil
        }
    }

    private static func debugLog(_ message: String) {
        #if DEBUG
        print("[TVDiscovery] \(message)")
        #endif
    }
}
