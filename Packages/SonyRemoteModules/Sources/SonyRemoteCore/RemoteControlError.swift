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
            "IP 地址无效"
        case .missingPSK:
            "缺少预共享密钥"
        case .missingDevice:
            "尚未配置电视"
        case .timeout, .unreachable:
            "无法连接电视"
        case .unauthorized:
            "认证失败"
        case .remoteControlUnavailable:
            "遥控服务不可用"
        case .invalidResponse:
            "电视响应异常"
        case .keychainFailure:
            "安全存储失败"
        case .unknown:
            "发生未知错误"
        }
    }

    public var recoverySuggestion: String {
        switch self {
        case .invalidIPAddress:
            "请输入有效的 IP 地址。"
        case .missingPSK:
            "请输入电视上配置的预共享密钥。"
        case .missingDevice:
            "请先添加一台 BRAVIA 电视。"
        case .timeout, .unreachable:
            "确认 iPhone 和电视在同一网络，且电视已开机。"
        case .unauthorized:
            "请检查电视上配置的预共享密钥。"
        case .remoteControlUnavailable:
            "请在电视设置中开启 IP 控制和远程设备控制。"
        case .invalidResponse:
            "电视返回内容不符合预期，请重试或检查电视设置。"
        case let .keychainFailure(message):
            message
        case let .unknown(message):
            message.isEmpty ? "请重试或检查电视设置。" : message
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
