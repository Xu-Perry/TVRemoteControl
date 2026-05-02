import Foundation

public enum BRAVIAConnectionReadiness: String, Codable, Equatable, Sendable {
    case connectable
    case paired
    case unavailable
    case unknown

    public var displayText: String {
        switch self {
        case .connectable:
            "可连接"
        case .paired:
            "已配对"
        case .unavailable:
            "不可用"
        case .unknown:
            "未知"
        }
    }
}

public struct DiscoveredBRAVIADevice: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var host: String
    public var port: Int
    public var uniqueIdentifier: String?
    public var connectionReadiness: BRAVIAConnectionReadiness
    public var lastSeenAt: Date

    public init(
        id: String? = nil,
        name: String,
        host: String,
        port: Int = 80,
        uniqueIdentifier: String? = nil,
        connectionReadiness: BRAVIAConnectionReadiness = .unknown,
        lastSeenAt: Date = Date()
    ) {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedIdentifier = uniqueIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id ?? Self.stableID(uniqueIdentifier: normalizedIdentifier, host: normalizedHost, port: port)
        self.name = normalizedName.isEmpty ? normalizedHost : normalizedName
        self.host = normalizedHost
        self.port = port
        self.uniqueIdentifier = normalizedIdentifier?.isEmpty == true ? nil : normalizedIdentifier
        self.connectionReadiness = connectionReadiness
        self.lastSeenAt = lastSeenAt
    }

    public var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? host : trimmedName
    }

    public func sonyDevice(pskKey: String = "", connectionMode: ConnectionMode = .normalPairing) -> SonyDevice {
        SonyDevice(
            name: displayName,
            host: host,
            port: port,
            pskKey: pskKey,
            connectionMode: connectionMode,
            lastConnectedAt: nil
        )
    }

    public static func stableID(uniqueIdentifier: String?, host: String, port: Int) -> String {
        if let uniqueIdentifier, !uniqueIdentifier.isEmpty {
            return uniqueIdentifier.lowercased()
        }
        return "\(host.lowercased()):\(port)"
    }
}
