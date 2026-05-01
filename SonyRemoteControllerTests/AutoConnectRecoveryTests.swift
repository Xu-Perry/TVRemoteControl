import Testing
import SonyRemoteNetworking
@testable import SonyRemoteController

@MainActor
struct AutoConnectRecoveryTests {
    @Test func noDevicesShowsRecoveryAndRetryStartsNewScan() async throws {
        let harness = AutoConnectHarness(discoveryEvents: [.finished([])])

        harness.viewModel.autoConnect.startScan()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(harness.state.autoConnect.screen == .noDevices)
        #expect(harness.state.autoConnect.discoveredDevices.isEmpty)

        harness.discoveryService.events = [.finished([.livingRoom])]
        harness.viewModel.autoConnect.startScan()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(harness.state.autoConnect.screen == .devicesFound)
        #expect(harness.state.autoConnect.discoveredDevices.count == 1)
    }

    @Test func manualEntryPresentsSettings() {
        let harness = AutoConnectHarness()

        harness.viewModel.autoConnect.openManualEntry()

        #expect(harness.state.isSettingsPresented)
        #expect(harness.state.autoConnect.isManualEntryPresented)
    }
}
