import Foundation
import SonyRemoteCore
import SonyRemoteNetworking

@MainActor
final class ConnectionDiagnosticsViewModel {
    let state: ConnectionDiagnosticsState

    private let pageState: RemotePageState
    private let repository: DeviceRepository
    private let braviaClient: BRAVIAControlling
    private let discoveryService: BRAVIADiscoveryServicing
    private var diagnosticsTask: Task<Void, Never>?

    init(
        state: ConnectionDiagnosticsState,
        pageState: RemotePageState,
        repository: DeviceRepository,
        braviaClient: BRAVIAControlling,
        discoveryService: BRAVIADiscoveryServicing
    ) {
        self.state = state
        self.pageState = pageState
        self.repository = repository
        self.braviaClient = braviaClient
        self.discoveryService = discoveryService
    }

    func startIfNeeded() {
        guard state.runState == .idle else { return }
        start()
    }

    func start() {
        diagnosticsTask?.cancel()
        state.resetForRun()

        diagnosticsTask = Task { [weak self] in
            guard let self else { return }
            await runDiagnostics()
        }
    }

    func cancel() {
        diagnosticsTask?.cancel()
        diagnosticsTask = nil
        if state.runState == .running {
            state.runState = .idle
            state.summary = "诊断已停止。"
        }
    }

    private func runDiagnostics() async {
        var discoveredDevices: [DiscoveredBRAVIADevice] = []

        state.update(
            .deviceReachability,
            status: .running,
            message: "正在扫描附近 BRAVIA 电视..."
        )

        do {
            for try await event in discoveryService.discover(timeout: 5) {
                try Task.checkCancellation()
                switch event {
                case let .deviceFound(device):
                    upsert(device, into: &discoveredDevices)
                    state.discoveredDevices = discoveredDevices
                case let .finished(devices):
                    for device in devices {
                        upsert(device, into: &discoveredDevices)
                    }
                    state.discoveredDevices = discoveredDevices
                }
            }

            if !discoveredDevices.isEmpty {
                // SSDP found devices → local network permission is definitely working.
                state.update(
                    .localNetworkPermission,
                    status: .passed,
                    message: "已成功扫描到本地设备，本地网络权限正常。"
                )
            }

            await finishDeviceDiagnosis(discoveredDevices)
        } catch is CancellationError {
            state.runState = .idle
            state.summary = "诊断已停止。"
        } catch {
            finishDiscoveryFailure(error)
        }
    }

    private func finishDeviceDiagnosis(_ discoveredDevices: [DiscoveredBRAVIADevice]) async {
        if !discoveredDevices.isEmpty {
            // Permission already marked as passed above (SSDP worked).
            state.update(
                .deviceReachability,
                status: .passed,
                message: "已发现 \(discoveredDevices.count) 台 BRAVIA 电视，可返回设备管理页选择并连接。"
            )
            state.update(
                .televisionSettings,
                status: .passed,
                message: "如果发现后仍无法配对，请在电视上开启远程设备控制、IP Control，并允许新的控制设备注册。"
            )
            state.summary = "诊断完成：已发现附近电视。"
            state.runState = .completed
            return
        }

        // SSDP returned zero devices — could be permission issue, no TV, or network problem.
        // iOS has no public API to query local network TCC status at runtime,
        // so we cannot definitively determine whether permission is the cause.
        // Instead, mark permission as inconclusive with guidance.
        state.update(
            .localNetworkPermission,
            status: .warning,
            message: "扫描未返回任何设备。如果已在系统设置中关闭了本地网络权限，请重新开启并彻底关闭 App 后再试。iOS 限制：更改权限后需要完全退出 App 才能生效。"
        )

        if await canReachSavedDevice() {
            state.update(
                .deviceReachability,
                status: .passed,
                message: "未通过扫描发现新设备，但已保存的电视可以直接连接。"
            )
            state.update(
                .televisionSettings,
                status: .passed,
                message: "已保存的电视可以正常连接，电视端设置正确。"
            )
            state.summary = "诊断完成：保存的电视可连接，自动发现未返回设备。"
        } else {
            state.update(
                .deviceReachability,
                status: .failed,
                message: "没有发现附近 BRAVIA，也无法确认已保存电视在线。请确认电视已开机，手机和电视连接同一个 Wi-Fi。"
            )
            state.update(
                .televisionSettings,
                status: .warning,
                message: "请到电视：设置 > 网络和互联网 > 家庭网络设置，开启远程设备控制；在 IP Control 中开启控制，并确认认证方式可用。"
            )
            state.summary = "诊断完成：未找到可连接的电视。"
        }

        state.runState = .completed
    }

    private func canReachSavedDevice() async -> Bool {
        guard let device = pageState.savedDevice else { return false }

        do {
            let credential = try repository.readCredential(for: device)
            try await braviaClient.testConnection(device: device, credential: credential)
            return true
        } catch {
            return false
        }
    }

    private func finishDiscoveryFailure(_ error: Error) {
        if isLocalNetworkPermissionFailure(error) {
            state.update(
                .localNetworkPermission,
                status: .failed,
                message: "本地网络发现不可用。请到 iOS 设置 > 隐私与安全性 > 本地网络，允许 Bravia Controller 访问本地网络。之后请彻底关闭 App 再重新打开。"
            )
            state.update(
                .deviceReachability,
                status: .pending,
                message: "本地网络权限恢复后，再重新运行诊断以扫描电视。"
            )
            state.update(
                .televisionSettings,
                status: .pending,
                message: "权限恢复前无法判断电视端设置。"
            )
            state.summary = "诊断完成：需要先开启本地网络权限。"
        } else {
            let message = RemoteControlError.map(error).recoverySuggestion
            state.update(
                .localNetworkPermission,
                status: .warning,
                message: "本地网络扫描启动后出现错误：\(message)"
            )
            state.update(
                .deviceReachability,
                status: .failed,
                message: "当前无法完成设备发现。请确认手机 Wi-Fi 可用，并稍后重试。"
            )
            state.update(
                .televisionSettings,
                status: .warning,
                message: "如果网络正常，请确认电视已开机，并开启远程设备控制和 IP Control。"
            )
            state.summary = "诊断完成：扫描过程失败。"
        }

        state.runState = .completed
    }

    private func upsert(_ device: DiscoveredBRAVIADevice, into devices: inout [DiscoveredBRAVIADevice]) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
        } else {
            devices.append(device)
        }
    }

    private func isLocalNetworkPermissionFailure(_ error: Error) -> Bool {
        if case DiscoveryError.networkUnavailable = error {
            return true
        }

        let description = String(describing: error).lowercased()
        return description.contains("permission")
            || description.contains("permitted")
            || description.contains("denied")
            || description.contains("policy")
            || description.contains("local network")
    }
}
