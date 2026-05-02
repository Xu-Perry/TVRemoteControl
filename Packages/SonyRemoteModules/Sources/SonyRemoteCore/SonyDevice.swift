import Foundation

public enum ConnectionMode: String, Codable, Equatable, Sendable {
    case psk
    case normalPairing
}

public struct SonyDevice: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var host: String
    public var port: Int
    public var pskKey: String
    public var connectionMode: ConnectionMode
    public var lastConnectedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 80,
        pskKey: String,
        connectionMode: ConnectionMode = .psk,
        lastConnectedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.pskKey = pskKey
        self.connectionMode = connectionMode
        self.lastConnectedAt = lastConnectedAt
    }

    public var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? host : trimmedName
    }
}

public extension SonyDevice {
    static func isValidIPv4Address(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }

        return parts.allSatisfy { part in
            guard !part.isEmpty, part.allSatisfy(\.isNumber), let number = Int(part) else {
                return false
            }
            return (0...255).contains(number)
        }
    }
}
