import Testing
import TVRemoteNetworking
@testable import TVRemoteController

@MainActor
struct AutoConnectRecoveryTests {
    @Test func noDevicesShowsRecoveryAndRetryStartsNewScan() async throws {
        let harness = AutoConnectHarness(discoveryEvents: [.finished([])])

        harness.viewModel.autoConnect.startScan()
        try await waitUntil { harness.state.autoConnect.screen == .noDevices }

        #expect(harness.state.autoConnect.screen == .noDevices)
        #expect(harness.state.autoConnect.discoveredDevices.isEmpty)

        harness.discoveryService.events = [.finished([.livingRoom])]
        harness.viewModel.autoConnect.startScan()
        try await waitUntil { harness.state.autoConnect.screen == .devicesFound }

        #expect(harness.state.autoConnect.screen == .devicesFound)
        #expect(harness.state.autoConnect.discoveredDevices.count == 1)
    }

    @Test func manualEntryPushesManualIPPageWithoutOpeningSettings() {
        let harness = AutoConnectHarness()

        harness.viewModel.autoConnect.openManualEntry()

        #expect(harness.state.autoConnect.isManualEntryPresented)
        #expect(!harness.state.isSettingsPresented)
        #expect(harness.state.settings.ipAddress.isEmpty)
        #expect(harness.state.settings.psk.isEmpty)
    }

    @Test func manualEntryCanBeDismissedFromNavigationBinding() {
        let harness = AutoConnectHarness()

        harness.viewModel.autoConnect.openManualEntry()
        harness.viewModel.autoConnect.closeManualEntry()

        #expect(!harness.state.autoConnect.isManualEntryPresented)
    }
}
