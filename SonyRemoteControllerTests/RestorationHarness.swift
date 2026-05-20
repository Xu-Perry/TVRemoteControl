import SonyRemoteCore
import SonyRemoteNetworking
@testable import SonyRemoteController

@MainActor
final class RestorationHarness {
    let state: RemotePageState
    let repository: RestorationMockDeviceRepository
    let client: RestorationMockBRAVIAClient
    let viewModel: RemotePageViewModel

    init(
        client: RestorationMockBRAVIAClient = RestorationMockBRAVIAClient(),
        haptics: RemoteHapticsProviding? = nil
    ) {
        state = RemotePageState()
        repository = RestorationMockDeviceRepository()
        self.client = client
        viewModel = RemotePageViewModel(
            state: state,
            repository: repository,
            braviaClient: client,
            pairingClient: client,
            discoveryService: RestorationEmptyDiscoveryService(),
            haptics: haptics
        )
    }

    func connectSavedDevice() async {
        state.settings.tvName = "Living Room"
        state.settings.ipAddress = "192.168.1.2"
        state.settings.psk = "1234"
        await viewModel.settings.testConnection()
        viewModel.saveSettings()
    }
}
