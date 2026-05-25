import Foundation
import Observation
import TVRemoteCore

enum ConnectionDiagnosticStepID: String, CaseIterable, Sendable {
    case localNetworkPermission
    case deviceReachability
    case televisionSettings
}

enum ConnectionDiagnosticStepStatus: Equatable, Sendable {
    case pending
    case running
    case passed
    case warning
    case failed
}

struct ConnectionDiagnosticStep: Identifiable, Equatable, Sendable {
    let id: ConnectionDiagnosticStepID
    var title: String
    var message: String
    var status: ConnectionDiagnosticStepStatus
}

enum ConnectionDiagnosticsRunState: Equatable, Sendable {
    case idle
    case running
    case completed
}

@Observable
@MainActor
final class ConnectionDiagnosticsState {
    var runState: ConnectionDiagnosticsRunState = .idle
    var summary = "进入页面后会自动检查本地网络权限、设备发现和电视端设置。"
    var steps: [ConnectionDiagnosticStep] = ConnectionDiagnosticsState.defaultSteps()
    var discoveredDevices: [DiscoveredTVDevice] = []

    var isRunning: Bool {
        runState == .running
    }

    func resetForRun() {
        runState = .running
        summary = "正在检查连接环境..."
        discoveredDevices = []
        steps = Self.defaultSteps()
    }

    func update(
        _ id: ConnectionDiagnosticStepID,
        status: ConnectionDiagnosticStepStatus,
        message: String
    ) {
        guard let index = steps.firstIndex(where: { $0.id == id }) else { return }
        steps[index].status = status
        steps[index].message = message
    }

    static func defaultSteps() -> [ConnectionDiagnosticStep] {
        [
            ConnectionDiagnosticStep(
                id: .localNetworkPermission,
                title: "本地网络权限",
                message: "确认系统已允许 App 访问本地网络，并具备本地设备发现能力。",
                status: .pending
            ),
            ConnectionDiagnosticStep(
                id: .deviceReachability,
                title: "发现电视",
                message: "扫描同一 Wi-Fi 下的电视，或测试已保存电视是否可连接。",
                status: .pending
            ),
            ConnectionDiagnosticStep(
                id: .televisionSettings,
                title: "电视端设置",
                message: "按诊断结果检查电视上的远程控制、IP Control 和认证选项。",
                status: .pending
            )
        ]
    }
}
