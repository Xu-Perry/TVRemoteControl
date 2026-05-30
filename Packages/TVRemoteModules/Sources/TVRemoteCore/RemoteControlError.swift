import Foundation

public enum RemoteControlError: Error, Equatable, Sendable {
    case invalidIPAddress
    case missingPSK
    case missingDevice
    case timeout
    case unreachable
    case unauthorized
    case remoteControlUnavailable
    case textInputInactive
    case textEncryptionFailed
    case requestInProgress
    case invalidResponse
    case keychainFailure(String)
    case pairingFailed
    case pairingPinInvalid
    case pairingTimedOut
    case pairingCancelled
    case pairingNotSupported
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
        case .textInputInactive:
            "电视输入框未激活"
        case .textEncryptionFailed:
            "文字加密失败"
        case .requestInProgress:
            "电视正忙"
        case .invalidResponse:
            "电视响应异常"
        case .keychainFailure:
            "安全存储失败"
        case .pairingFailed:
            "配对失败"
        case .pairingPinInvalid:
            "PIN 码无效"
        case .pairingTimedOut:
            "配对超时"
        case .pairingCancelled:
            "配对已取消"
        case .pairingNotSupported:
            "该电视不支持注册配对"
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
            "请先添加一台电视。"
        case .timeout, .unreachable:
            "确认 iPhone 和电视在同一网络，且电视已开机。"
        case .unauthorized:
            "请检查电视上配置的预共享密钥。"
        case .remoteControlUnavailable:
            "请在电视设置中开启 IP 控制和远程设备控制。"
        case .textInputInactive:
            "请先在电视上打开需要输入文字的界面，并确保电视屏幕上的输入框已获得焦点。"
        case .textEncryptionFailed:
            "无法加密要发送的文字，请重试。"
        case .requestInProgress:
            "电视仍在处理上一条文字请求，请稍后重试。"
        case .invalidResponse:
            "电视返回内容不符合预期，请重试或检查电视设置。"
        case let .keychainFailure(message):
            message
        case .pairingFailed:
            "电视拒绝了配对请求，请重试或使用预共享密钥手动连接。"
        case .pairingPinInvalid:
            "PIN 码错误，请检查电视屏幕上显示的数字后重新输入。"
        case .pairingTimedOut:
            "配对超时，请重新发起配对并在电视显示 PIN 码后及时输入。"
        case .pairingCancelled:
            "已取消配对。"
        case .pairingNotSupported:
            "该电视不支持注册配对模式，请使用预共享密钥手动连接。"
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

        if let discoveryError = error as? DiscoveryError {
            switch discoveryError {
            case .cancelled:
                return .unknown("已取消发现设备。")
            case .networkUnavailable:
                return .unreachable
            case .noDevices:
                return .missingDevice
            case .malformedDeviceDescription:
                return .invalidResponse
            case let .unknown(message):
                return .unknown(message)
            }
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
