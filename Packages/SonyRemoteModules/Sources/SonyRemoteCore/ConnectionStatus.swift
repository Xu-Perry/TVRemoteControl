public enum ConnectionStatus: Equatable, Sendable {
    case noDevice
    case disconnected
    case connecting
    case connected
    case failed(RemoteControlError)

    public var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }

    public var allowsRemoteCommands: Bool {
        isConnected
    }

    public var displayText: String {
        switch self {
        case .noDevice:
            "Add a TV to start"
        case .disconnected:
            "Disconnected"
        case .connecting:
            "Connecting..."
        case .connected:
            "Connected"
        case .failed:
            "Connection failed"
        }
    }
}
