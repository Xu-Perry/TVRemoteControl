import Testing
import SonyRemoteCore
import SonyRemoteNetworking
@testable import SonyRemoteController

@MainActor
struct AutoConnectConnectionTests {
    @Test func selectingDiscoveredDeviceInitiatesPairingAndShowsPinSheet() async throws {
        let harness = AutoConnectHarness()

        harness.viewModel.autoConnect.select(.livingRoom)
        try await waitUntil { harness.state.autoConnect.isPinSheetPresented }

        #expect(harness.state.autoConnect.screen == .connecting)
        #expect(harness.state.autoConnect.isPinSheetPresented)
        #expect(harness.state.autoConnect.pairingSession?.registrationID == "mock-reg-1234")
    }

    @Test func submittingPinCompletesPairingAndConnectsDevice() async throws {
        let harness = AutoConnectHarness()

        harness.viewModel.autoConnect.select(.livingRoom)
        try await waitUntil { harness.state.autoConnect.isPinSheetPresented }

        harness.state.autoConnect.pairingPIN = "1234"
        harness.viewModel.autoConnect.submitPIN()
        try await waitUntil { harness.state.autoConnect.screen == .connectedReady }

        #expect(harness.state.autoConnect.screen == .connectedReady)
        #expect(!harness.state.autoConnect.isPinSheetPresented)
        #expect(harness.state.savedDevice?.displayName == "BRAVIA XR-65A80L")
        #expect(harness.state.status == .connected)
        #expect(harness.state.remotePad.isEnabled)

        harness.viewModel.autoConnect.enterRemote()

        #expect(!harness.state.isAutoConnectPresented)
    }

    @Test func dismissingPinSheetReturnsToDevicesFound() async throws {
        let harness = AutoConnectHarness(discoveryEvents: [
            .deviceFound(.livingRoom),
            .finished([.livingRoom])
        ])
        harness.viewModel.autoConnect.startScan()
        try await waitUntil { harness.state.autoConnect.screen == .devicesFound }

        harness.viewModel.autoConnect.select(.livingRoom)
        try await waitUntil { harness.state.autoConnect.isPinSheetPresented }

        harness.viewModel.autoConnect.dismissPinSheet()

        #expect(!harness.state.autoConnect.isPinSheetPresented)
        #expect(harness.state.autoConnect.screen == .devicesFound)
    }
}

@MainActor
func waitUntil(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    condition: @escaping @MainActor () -> Bool
) async throws {
    let deadline = ContinuousClock.now + .nanoseconds(Int(timeoutNanoseconds))
    while ContinuousClock.now < deadline {
        if condition() {
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(condition())
}
