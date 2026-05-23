import Foundation

public struct PairingSession: Equatable, Sendable {
    public let clientID: String
    public var registrationID: String?
    public var deviceName: String

    public init(clientID: String? = nil, registrationID: String? = nil, deviceName: String = "") {
        self.clientID = clientID ?? "tv-remote:\(UUID().uuidString)"
        self.registrationID = registrationID
        self.deviceName = deviceName
    }
}
