import Testing
import SonyRemoteCore
@testable import SonyRemoteController

@MainActor
struct AutoConnectConnectionTests {
    @Test func selectingDiscoveredDeviceConnectsAndEntersRemote() async throws {
        let harness = AutoConnectHarness()

        harness.viewModel.autoConnect.select(.livingRoom)
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(harness.state.autoConnect.screen == .connectedReady)
        #expect(harness.state.savedDevice?.displayName == "BRAVIA XR-65A80L")
        #expect(harness.state.status == .connected)
        #expect(harness.state.remotePad.isEnabled)

        harness.viewModel.autoConnect.enterRemote()

        #expect(!harness.state.isAutoConnectPresented)
    }
}
