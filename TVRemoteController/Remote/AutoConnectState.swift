import Foundation
import Observation
import TVRemoteCore

enum AutoConnectScreen: Equatable {
    case firstLaunch
    case scanning
    case devicesFound
    case connecting
    case connectedReady
    case noDevices
    case clearConfirmation
}

@Observable
@MainActor
final class AutoConnectState {
    var screen: AutoConnectScreen = .firstLaunch
    var session = DiscoverySessionState()
    var discoveredDevices: [DiscoveredTVDevice] = []
    var selectedDevice: DiscoveredTVDevice?
    var rememberedDevice: TVDevice?
    var connectionError: RemoteControlError?
    var isManualEntryPresented = false
    var isPinSheetPresented = false
    var pairingPIN: String = ""
    var pairingSession: PairingSession?
    var isPairingInProgress: Bool = false

    var title: String {
        switch screen {
        case .firstLaunch:
            "连接电视"
        case .scanning:
            "正在扫描附近设备"
        case .devicesFound:
            "选择要连接的电视"
        case .connecting:
            "正在连接电视"
        case .connectedReady, .clearConfirmation:
            "\(selectedDevice?.displayName ?? rememberedDevice?.displayName ?? "电视") 已准备就绪。"
        case .noDevices:
            "未发现设备"
        }
    }

    var subtitle: String {
        switch screen {
        case .firstLaunch:
            "首次使用前，请先扫描同一网络中的电视。"
        case .scanning:
            "正在搜索同一网络中的电视。"
        case .devicesFound:
            "发现 \(discoveredDevices.count) 台附近设备，选择一台开始连接。"
        case .connecting:
            "已选择 \(selectedDevice?.displayName ?? "电视")，正在建立连接。"
        case .connectedReady, .clearConfirmation:
            "连接后会自动记住设备，下次打开 App 可直接进入遥控器。"
        case .noDevices:
            "没有找到同一网络中的电视。"
        }
    }
}
