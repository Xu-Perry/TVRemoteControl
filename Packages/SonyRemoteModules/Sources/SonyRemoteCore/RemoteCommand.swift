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
    case channelUp = "ChannelUp"
    case channelDown = "ChannelDown"
    case input = "Input"
    case hdmi1 = "Hdmi1"
    case hdmi2 = "Hdmi2"
    case hdmi3 = "Hdmi3"
    case num0 = "Num0"
    case num1 = "Num1"
    case num2 = "Num2"
    case num3 = "Num3"
    case num4 = "Num4"
    case num5 = "Num5"
    case num6 = "Num6"
    case num7 = "Num7"
    case num8 = "Num8"
    case num9 = "Num9"
    case syncMenu = "SyncMenu"
    case display = "Display"
    case options = "Options"

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
        case .channelUp:
            "AAAAAQAAAAEAAAAQAw=="
        case .channelDown:
            "AAAAAQAAAAEAAAARAw=="
        case .input:
            "AAAAAQAAAAEAAAAlAw=="
        case .hdmi1:
            "AAAAAgAAABoAAABaAw=="
        case .hdmi2:
            "AAAAAgAAABoAAABbAw=="
        case .hdmi3:
            "AAAAAgAAABoAAABcAw=="
        case .num0:
            "AAAAAQAAAAEAAAAJAw=="
        case .num1:
            "AAAAAQAAAAEAAAAAAw=="
        case .num2:
            "AAAAAQAAAAEAAAABAw=="
        case .num3:
            "AAAAAQAAAAEAAAACAw=="
        case .num4:
            "AAAAAQAAAAEAAAADAw=="
        case .num5:
            "AAAAAQAAAAEAAAAEAw=="
        case .num6:
            "AAAAAQAAAAEAAAAFAw=="
        case .num7:
            "AAAAAQAAAAEAAAAGAw=="
        case .num8:
            "AAAAAQAAAAEAAAAHAw=="
        case .num9:
            "AAAAAQAAAAEAAAAIAw=="
        case .syncMenu:
            "AAAAAgAAABoAAABYAw=="
        case .display:
            "AAAAAQAAAAEAAAA6Aw=="
        case .options:
            "AAAAAgAAAJcAAAA2Aw=="
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
        case .channelUp:
            "Channel Up"
        case .channelDown:
            "Channel Down"
        case .input:
            "Input"
        case .hdmi1:
            "HDMI 1"
        case .hdmi2:
            "HDMI 2"
        case .hdmi3:
            "HDMI 3"
        case .num0:
            "0"
        case .num1:
            "1"
        case .num2:
            "2"
        case .num3:
            "3"
        case .num4:
            "4"
        case .num5:
            "5"
        case .num6:
            "6"
        case .num7:
            "7"
        case .num8:
            "8"
        case .num9:
            "9"
        case .syncMenu:
            "Menu"
        case .display:
            "Info"
        case .options:
            "Options"
        }
    }
}
