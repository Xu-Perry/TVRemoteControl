import TVRemoteCore
import TVRemoteNetworking

final class RestorationMockTVRemoteClient: TVRemoteControlling, TVPairing, @unchecked Sendable {
    private(set) var sentCommands: [RemoteCommand] = []
    private(set) var sentTexts: [String] = []
    var sendError: RemoteControlError?
    var sendTextError: RemoteControlError?

    func testConnection(device: TVDevice, credential: TVAuthCredential) async throws {
    }

    func send(command: RemoteCommand, device: TVDevice, credential: TVAuthCredential) async throws {
        sentCommands.append(command)
        if let sendError {
            throw sendError
        }
    }

    func sendText(_ text: String, device: TVDevice, credential: TVAuthCredential) async throws {
        sentTexts.append(text)
        if let sendTextError {
            throw sendTextError
        }
    }

    func initiatePairing(device: TVDevice, clientID: String) async throws -> String {
        "mock-reg"
    }

    func confirmPairingPIN(device: TVDevice, registrationID: String, pin: String, clientID: String) async throws -> String {
        "auth=mock-cookie"
    }

    func cancelPairing(clientID: String) async {
    }
}
