import Foundation

public enum RemoteControlError: Error, Equatable, Sendable {
    case invalidIPAddress
    case missingPSK
    case missingDevice
    case timeout
    case unreachable
    case unauthorized
    case remoteControlUnavailable
    case invalidResponse
    case keychainFailure(String)
    case unknown(String)

    public var title: String {
        switch self {
        case .invalidIPAddress:
            "Invalid IP Address"
        case .missingPSK:
            "Missing Pre-Shared Key"
        case .missingDevice:
            "No TV Configured"
        case .timeout, .unreachable:
            "TV Not Reachable"
        case .unauthorized:
            "Authentication Failed"
        case .remoteControlUnavailable:
            "Remote Control Unavailable"
        case .invalidResponse:
            "Unexpected TV Response"
        case .keychainFailure:
            "Secure Storage Failed"
        case .unknown:
            "Unexpected Error"
        }
    }

    public var recoverySuggestion: String {
        switch self {
        case .invalidIPAddress:
            "Enter a valid IP address."
        case .missingPSK:
            "Enter the Pre-Shared Key configured on the TV."
        case .missingDevice:
            "Add a BRAVIA TV before using the remote."
        case .timeout, .unreachable:
            "Check that your iPhone and TV are on the same network and that the TV is awake."
        case .unauthorized:
            "Check the Pre-Shared Key configured on the TV."
        case .remoteControlUnavailable:
            "Enable IP Control and Remote Device Control on the TV."
        case .invalidResponse:
            "The TV did not respond as expected. Try again or check the TV settings."
        case let .keychainFailure(message):
            message
        case let .unknown(message):
            message.isEmpty ? "Try again or check the TV settings." : message
        }
    }
}

public extension RemoteControlError {
    static func map(_ error: Error) -> RemoteControlError {
        if let remoteError = error as? RemoteControlError {
            return remoteError
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut:
                return .timeout
            case NSURLErrorCannotConnectToHost,
                 NSURLErrorCannotFindHost,
                 NSURLErrorDNSLookupFailed,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet:
                return .unreachable
            default:
                return .unknown(nsError.localizedDescription)
            }
        }

        return .unknown(nsError.localizedDescription)
    }
}
