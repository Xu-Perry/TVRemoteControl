import Foundation

public enum DiscoverySessionPhase: String, Codable, Equatable, Sendable {
    case idle
    case scanning
    case devicesFound
    case noDevices
    case cancelled
    case failed
}

public struct DiscoverySessionState: Codable, Equatable, Sendable {
    public var id: UUID
    public var phase: DiscoverySessionPhase
    public var devices: [DiscoveredTVDevice]
    public var startedAt: Date?
    public var completedAt: Date?
    public var message: String?

    public init(
        id: UUID = UUID(),
        phase: DiscoverySessionPhase = .idle,
        devices: [DiscoveredTVDevice] = [],
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        message: String? = nil
    ) {
        self.id = id
        self.phase = phase
        self.devices = devices
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.message = message
    }
}
