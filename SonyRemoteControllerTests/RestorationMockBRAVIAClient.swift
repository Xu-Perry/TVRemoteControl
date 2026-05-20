import SonyRemoteCore
import SonyRemoteNetworking

final class RestorationMockBRAVIAClient: BRAVIAControlling, BRAVIAPairing, @unchecked Sendable {
    private(set) var sentCommands: [RemoteCommand] = []
    private(set) var sentTexts: [String] = []
    var sendError: RemoteControlError?
    var sendTextError: RemoteControlError?

    func testConnection(device: SonyDevice, credential: BRAVIAAuthCredential) async throws {
    }

    func send(command: RemoteCommand, device: SonyDevice, credential: BRAVIAAuthCredential) async throws {
        sentCommands.append(command)
        if let sendError {
            throw sendError
        }
    }

    func sendText(_ text: String, device: SonyDevice, credential: BRAVIAAuthCredential) async throws {
        sentTexts.append(text)
        if let sendTextError {
            throw sendTextError
        }
    }

    func initiatePairing(device: SonyDevice, clientID: String) async throws -> String {
        "mock-reg"
    }

    func confirmPairingPIN(device: SonyDevice, registrationID: String, pin: String, clientID: String) async throws -> String {
        "auth=mock-cookie"
    }

    func cancelPairing(clientID: String) async {
    }
}
