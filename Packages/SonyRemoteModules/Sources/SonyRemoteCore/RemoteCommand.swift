public enum RemoteCommand: String, CaseIterable, Codable, Equatable, Sendable {
    case power = "Power"
    case home = "Home"
    case back = "Back"
    case up = "Up"
    case down = "Down"
    case left = "Left"
    case right = "Right"
    case confirm = "Confirm"
    case volumeUp = "VolumeUp"
    case volumeDown = "VolumeDown"
    case mute = "Mute"

    public var irccCode: String {
        switch self {
        case .power:
            "AAAAAQAAAAEAAAAVAw=="
        case .home:
            "AAAAAQAAAAEAAABgAw=="
        case .back:
            "AAAAAgAAAJcAAAAjAw=="
        case .up:
            "AAAAAQAAAAEAAAB0Aw=="
        case .down:
            "AAAAAQAAAAEAAAB1Aw=="
        case .left:
            "AAAAAQAAAAEAAAA0Aw=="
        case .right:
            "AAAAAQAAAAEAAAAzAw=="
        case .confirm:
            "AAAAAQAAAAEAAABlAw=="
        case .volumeUp:
            "AAAAAQAAAAEAAAASAw=="
        case .volumeDown:
            "AAAAAQAAAAEAAAATAw=="
        case .mute:
            "AAAAAQAAAAEAAAAUAw=="
        }
    }

    public var accessibilityLabel: String {
        switch self {
        case .power:
            "Power"
        case .home:
            "Home"
        case .back:
            "Back"
        case .up:
            "Up"
        case .down:
            "Down"
        case .left:
            "Left"
        case .right:
            "Right"
        case .confirm:
            "Confirm"
        case .volumeUp:
            "Volume Up"
        case .volumeDown:
            "Volume Down"
        case .mute:
            "Mute"
        }
    }
}
