import Testing
import SonyRemoteCore
import SonyRemoteNetworking
@testable import SonyRemoteController

@MainActor
struct ConnectionDiagnosticsTests {
    @Test func diagnosticsReportsDiscoveredDevices() async throws {
        let harness = AutoConnectHarness(discoveryEvents: [
            .deviceFound(.livingRoom),
            .finished([.livingRoom])
        ])

        harness.viewModel.connectionDiagnostics.start()
        try await waitUntil { harness.state.connectionDiagnostics.runState == .completed }

        #expect(harness.state.connectionDiagnostics.discoveredDevices == [.livingRoom])
        #expect(harness.state.connectionDiagnostics.status(for: .localNetworkPermission) == .passed)
        #expect(harness.state.connectionDiagnostics.status(for: .deviceReachability) == .passed)
        #expect(harness.state.connectionDiagnostics.status(for: .televisionSettings) == .passed)
    }

    @Test func diagnosticsGuidesUserWhenNoDeviceIsFound() async throws {
        let harness = AutoConnectHarness(discoveryEvents: [
            .finished([])
        ])

        harness.viewModel.connectionDiagnostics.start()
        try await waitUntil { harness.state.connectionDiagnostics.runState == .completed }

        #expect(harness.state.connectionDiagnostics.status(for: .localNetworkPermission) == .warning)
        #expect(harness.state.connectionDiagnostics.status(for: .deviceReachability) == .failed)
        #expect(harness.state.connectionDiagnostics.status(for: .televisionSettings) == .warning)
        #expect(harness.state.connectionDiagnostics.summary == "诊断完成：未找到可连接的电视。")
    }

    @Test func diagnosticsReportsLocalNetworkPermissionFailure() async throws {
        let harness = AutoConnectHarness(discoveryError: DiscoveryError.networkUnavailable)

        harness.viewModel.connectionDiagnostics.start()
        try await waitUntil { harness.state.connectionDiagnostics.runState == .completed }

        #expect(harness.state.connectionDiagnostics.status(for: .localNetworkPermission) == .failed)
        #expect(harness.state.connectionDiagnostics.status(for: .deviceReachability) == .pending)
        #expect(harness.state.connectionDiagnostics.status(for: .televisionSettings) == .pending)
        #expect(harness.state.connectionDiagnostics.summary == "诊断完成：需要先开启本地网络权限。")
    }
}

private extension ConnectionDiagnosticsState {
    func status(for id: ConnectionDiagnosticStepID) -> ConnectionDiagnosticStepStatus? {
        steps.first { $0.id == id }?.status
    }
}
