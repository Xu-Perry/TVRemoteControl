import Foundation
import Observation
import SonyRemoteCore

@Observable
@MainActor
final class RemotePageState {
    var connection = ConnectionHeaderState()
    var settings = DeviceSettingsState()
    var remotePad = RemotePadState()
    var savedDevice: SonyDevice?
    var status: ConnectionStatus = .noDevice
    var error: RemoteControlError?
    var isSettingsPresented = false

    var canSendCommands: Bool {
        status.allowsRemoteCommands
    }
}

@Observable
@MainActor
final class ConnectionHeaderState {
    var title = "No TV Connected"
    var subtitle = "Add a BRAVIA TV to start"
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
}

@Observable
@MainActor
final class RemotePadState {
    var isEnabled = false
    var lastCommand: RemoteCommand?
    var isSendingCommand = false
}
