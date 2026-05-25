import Foundation
import Observation
import TVRemoteCore

@Observable
@MainActor
final class RemotePageState {
    var connection = ConnectionHeaderState()
    var settings = DeviceSettingsState()
    var connectionDiagnostics = ConnectionDiagnosticsState()
    var remotePad = RemotePadState()
    var autoConnect = AutoConnectState()
    var presentedRemoteSurface: RemoteSurface?
    var isKeyboardInputActive = false
    var inputSources = InputSourceOption.defaultOptions()
    var keyboardDraft = KeyboardDraft()
    var moreKeyActions = MoreKeyAction.defaultActions()
    var remotePreferences = RemotePreferences()
    var savedDevice: TVDevice?
    var status: ConnectionStatus = .noDevice
    var error: RemoteControlError?
    var isSettingsPresented = false
    var isAutoConnectPresented = true

    var canSendCommands: Bool {
        status.allowsRemoteCommands
    }
}

@Observable
@MainActor
final class ConnectionHeaderState {
    var title = "No TV Connected"
    var subtitle = "Add a TV to start"
}

@Observable
@MainActor
final class DeviceSettingsState {
    var tvName = ""
    var ipAddress = ""
    var psk = ""
    var isTestingConnection = false
    var canSave = false
    var lastTestedHost: String?
    var error: RemoteControlError?
    var successMessage: String?
    var presentedRoute: SettingsRoute?
}

enum SettingsRoute: Hashable, Identifiable, Sendable {
    case deviceManagement
    case connectionDiagnostics
    case help
    case about

    var id: Self { self }
}

@Observable
@MainActor
final class RemotePadState {
    var isEnabled = false
    var lastCommand: RemoteCommand?
    var isSendingCommand = false
}

enum RemoteSurface: Equatable, Sendable {
    case inputSourceSheet
    case moreKeysSheet
}

struct InputSourceOption: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let symbolName: String
    let command: RemoteCommand?
    var isSelected: Bool

    static func defaultOptions() -> [InputSourceOption] {
        [
            InputSourceOption(id: "tv", title: "电视直播", symbolName: "tv", command: .input, isSelected: false),
            InputSourceOption(id: "hdmi1", title: "HDMI 1", symbolName: "rectangle", command: .hdmi1, isSelected: true),
            InputSourceOption(id: "hdmi2", title: "HDMI 2", symbolName: "rectangle", command: .hdmi2, isSelected: false),
            InputSourceOption(id: "hdmi3", title: "HDMI 3", symbolName: "rectangle", command: .hdmi3, isSelected: false),
            InputSourceOption(id: "hdmi4", title: "HDMI 4", symbolName: "rectangle", command: .hdmi4, isSelected: false),
            InputSourceOption(id: "usb", title: "USB", symbolName: "externaldrive", command: nil, isSelected: false)
        ]
    }
}

struct KeyboardDraft: Equatable, Sendable {
    var text = ""
    var maxLength = 500
    var status: KeyboardDraftStatus = .empty
    var errorMessage: String?

    var characterCountText: String {
        "\(text.count)/\(maxLength)"
    }

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSend: Bool {
        !trimmedText.isEmpty && status != .sending
    }

    var statusText: String {
        switch status {
        case .empty:
            "未输入"
        case .editing:
            "输入中"
        case .sending:
            "发送中..."
        case .sent:
            "已发送到电视"
        case .failed:
            "发送失败"
        }
    }
}

enum KeyboardDraftStatus: Equatable, Sendable {
    case empty
    case editing
    case sending
    case sent
    case failed
}

struct MoreKeyAction: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let symbolName: String?
    let command: RemoteCommand?

    var isSupported: Bool {
        command != nil
    }

    static func defaultActions() -> [MoreKeyAction] {
        [
            MoreKeyAction(id: "num1", title: "1", symbolName: nil, command: .num1),
            MoreKeyAction(id: "num2", title: "2", symbolName: nil, command: .num2),
            MoreKeyAction(id: "num3", title: "3", symbolName: nil, command: .num3),
            MoreKeyAction(id: "num4", title: "4", symbolName: nil, command: .num4),
            MoreKeyAction(id: "num5", title: "5", symbolName: nil, command: .num5),
            MoreKeyAction(id: "num6", title: "6", symbolName: nil, command: .num6),
            MoreKeyAction(id: "num7", title: "7", symbolName: nil, command: .num7),
            MoreKeyAction(id: "num8", title: "8", symbolName: nil, command: .num8),
            MoreKeyAction(id: "num9", title: "9", symbolName: nil, command: .num9),
            MoreKeyAction(id: "spacer-left", title: "", symbolName: nil, command: nil),
            MoreKeyAction(id: "num0", title: "0", symbolName: nil, command: .num0),
            MoreKeyAction(id: "spacer-right", title: "", symbolName: nil, command: nil),
            MoreKeyAction(id: "menu", title: "菜单", symbolName: "list.bullet", command: .syncMenu),
            MoreKeyAction(id: "back", title: "返回", symbolName: "arrow.uturn.backward", command: .back),
            MoreKeyAction(id: "info", title: "信息", symbolName: "info", command: .display),
            MoreKeyAction(id: "options", title: "选项", symbolName: "ellipsis", command: .options)
        ]
    }
}

struct RemotePreferences: Equatable, Sendable {
    var isHapticFeedbackEnabled = true
}
