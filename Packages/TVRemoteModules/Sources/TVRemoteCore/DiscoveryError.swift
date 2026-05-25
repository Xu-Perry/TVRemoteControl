import Foundation

public enum DiscoveryError: Error, Equatable, LocalizedError, Sendable {
    case noDevices
    case cancelled
    case malformedDeviceDescription
    case networkUnavailable
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .noDevices:
            "No compatible TVs were discovered on the local network."
        case .cancelled:
            "Discovery was cancelled."
        case .malformedDeviceDescription:
            "A discovered device returned an invalid description."
        case .networkUnavailable:
            "Local network discovery is unavailable. Check Wi-Fi, local network permission, and multicast entitlement."
        case let .unknown(message):
            message.isEmpty ? "Unknown discovery error." : message
        }
    }
}
