import SonyRemoteCore
import SonyRemoteNetworking

final class RestorationMockBRAVIAClient: BRAVIAControlling, BRAVIAPairing, @unchecked Sendable {
    private(set) var sentCommands: [RemoteCommand] = []

    func testConnection(device: SonyDevice, credential: BRAVIAAuthCredential) async throws {
    }

    func send(command: RemoteCommand, device: SonyDevice, credential: BRAVIAAuthCredential) async throws {
        sentCommands.append(command)
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
