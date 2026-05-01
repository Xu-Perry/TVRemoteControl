import Foundation

public enum DiscoveryError: Error, Equatable, Sendable {
    case noDevices
    case cancelled
    case malformedDeviceDescription
    case networkUnavailable
    case unknown(String)
}
