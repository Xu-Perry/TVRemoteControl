import Testing
import TVRemoteCore
@testable import TVRemoteController

@MainActor
struct AutoConnectPersistenceTests {
    @Test func restoresRememberedDeviceAndClearsAfterConfirmation() {
        let state = RemotePageState()
        let repository = AutoConnectMockDeviceRepository()
        let savedDevice = TVDevice(name: "Living Room", host: "192.168.1.20", pskKey: "key")
        repository.stubDevice(savedDevice, psk: "")

        let viewModel = RemotePageViewModel(
            state: state,
            repository: repository,
            tvRemoteClient: AutoConnectMockTVRemoteClient(),
            pairingClient: AutoConnectMockTVRemoteClient(),
            discoveryService: AutoConnectFakeDiscoveryService(events: [])
        )

        #expect(state.savedDevice == savedDevice)
        #expect(!state.isAutoConnectPresented)

        viewModel.autoConnect.restoreRememberedDevice(savedDevice)
        viewModel.autoConnect.showClearConfirmation()
        viewModel.autoConnect.clearRememberedConnection()

        #expect(state.savedDevice == nil)
        #expect(state.status == .noDevice)
        #expect(state.isAutoConnectPresented)
        #expect(state.autoConnect.screen == .firstLaunch)
    }
}
