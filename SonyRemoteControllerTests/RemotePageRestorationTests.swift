import Foundation
import Testing
import SonyRemoteCore
import SonyRemoteNetworking
@testable import SonyRemoteController

@MainActor
struct RemotePageRestorationTests {
    @Test func connectedStateShowsMainRemoteSurface() async {
        let harness = RestorationHarness()

        await harness.connectSavedDevice()

        #expect(harness.state.status == .connected)
        #expect(!harness.state.isAutoConnectPresented)
        #expect(harness.state.presentedRemoteSurface == nil)
        #expect(!harness.state.isKeyboardInputActive)
        #expect(harness.state.remotePad.isEnabled)
        #expect(harness.state.inputSources.map(\.title) == ["电视直播", "HDMI 1", "HDMI 2", "HDMI 3", "USB"])
        #expect(harness.state.moreKeyActions.map(\.title) == [
            "1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "",
            "菜单", "返回", "信息", "选项"
        ])
        #expect(!harness.state.moreKeyActions.contains { $0.title == "播放/暂停" })
    }

    @Test func commandSendKeepsRemotePagePresentationStable() async {
        let harness = RestorationHarness()
        await harness.connectSavedDevice()
        let snapshot = RestorationPageSnapshot(state: harness.state)

        await harness.viewModel.remotePad.send(.home)

        #expect(harness.client.sentCommands == [.home])
        snapshot.assertStillMatches(harness.state)
    }

    @Test func noDeviceStateKeepsAutoConnectEntryPath() {
        let harness = RestorationHarness()

        #expect(harness.state.status == .noDevice)
        #expect(harness.state.isAutoConnectPresented)
        #expect(harness.state.presentedRemoteSurface == nil)
        #expect(!harness.state.isKeyboardInputActive)
        #expect(!harness.state.remotePad.isEnabled)
    }

    @Test func secondarySurfacesOpenAndDismissWithoutChangingDevice() async {
        let harness = RestorationHarness()
        await harness.connectSavedDevice()
        let savedDevice = harness.state.savedDevice

        harness.viewModel.openInputSourceSheet()
        #expect(harness.state.presentedRemoteSurface == .inputSourceSheet)
        harness.viewModel.dismissRemoteSurface()
        #expect(harness.state.presentedRemoteSurface == nil)

        harness.viewModel.openKeyboardInput()
        #expect(harness.state.presentedRemoteSurface == nil)
        #expect(harness.state.isKeyboardInputActive)
        harness.viewModel.closeKeyboardInput()
        #expect(harness.state.presentedRemoteSurface == nil)
        #expect(!harness.state.isKeyboardInputActive)

        harness.viewModel.openMoreKeysSheet()
        #expect(harness.state.presentedRemoteSurface == .moreKeysSheet)
        harness.viewModel.dismissRemoteSurface()
        #expect(harness.state.presentedRemoteSurface == nil)

        #expect(harness.state.savedDevice == savedDevice)
        #expect(harness.state.status == .connected)
    }

    @Test func keyboardInputActivationKeepsMainRemotePresentationStable() async {
        let harness = RestorationHarness()
        await harness.connectSavedDevice()
        let snapshot = RestorationPageSnapshot(state: harness.state)

        harness.viewModel.openKeyboardInput()

        #expect(harness.state.isKeyboardInputActive)
        #expect(harness.state.presentedRemoteSurface == nil)
        snapshot.assertStillMatches(harness.state)
    }

    @Test func keyboardDraftClearDeleteAndCountUseConnectedTarget() async {
        let harness = RestorationHarness()
        await harness.connectSavedDevice()
        harness.viewModel.updateKeyboardDraftText("SONY")

        #expect(harness.state.keyboardDraft.characterCountText == "4/500")
        #expect(harness.state.keyboardDraft.status == .editing)

        harness.viewModel.deleteLastKeyboardCharacter()
        #expect(harness.state.keyboardDraft.text == "SON")
        #expect(harness.state.keyboardDraft.characterCountText == "3/500")

        harness.viewModel.clearKeyboardDraft()
        #expect(harness.state.keyboardDraft.text.isEmpty)
        #expect(harness.state.keyboardDraft.status == .empty)
        #expect(harness.state.savedDevice?.displayName == "Living Room")
    }

    @Test func closingKeyboardInputPreservesDraftText() async {
        let harness = RestorationHarness()
        await harness.connectSavedDevice()
        harness.viewModel.openKeyboardInput()
        harness.viewModel.updateKeyboardDraftText("SONY")

        harness.viewModel.closeKeyboardInput()

        #expect(!harness.state.isKeyboardInputActive)
        #expect(harness.state.keyboardDraft.text == "SONY")
        #expect(harness.state.keyboardDraft.status == .editing)
    }

    @Test func emptyKeyboardDraftDoesNotSendText() async {
        let harness = RestorationHarness()
        await harness.connectSavedDevice()

        await harness.viewModel.sendKeyboardDraft()

        #expect(harness.client.sentTexts.isEmpty)
        #expect(harness.state.keyboardDraft.status == .empty)
        #expect(harness.state.keyboardDraft.errorMessage == "请输入要发送到电视的文字。")
    }

    @Test func keyboardDraftSendsTrimmedTextToConnectedTV() async {
        let harness = RestorationHarness()
        await harness.connectSavedDevice()
        harness.viewModel.updateKeyboardDraftText("  Sony TV  ")

        await harness.viewModel.sendKeyboardDraft()

        #expect(harness.client.sentTexts == ["Sony TV"])
        #expect(harness.state.keyboardDraft.status == .sent)
        #expect(harness.state.keyboardDraft.errorMessage == nil)
    }

    @Test func keyboardDraftFailureKeepsTextAndShowsFailedState() async {
        let harness = RestorationHarness()
        await harness.connectSavedDevice()
        harness.client.sendTextError = .remoteControlUnavailable
        harness.viewModel.updateKeyboardDraftText("Sony")

        await harness.viewModel.sendKeyboardDraft()

        #expect(harness.client.sentTexts == ["Sony"])
        #expect(harness.state.keyboardDraft.text == "Sony")
        #expect(harness.state.keyboardDraft.status == .failed)
        #expect(harness.state.keyboardDraft.errorMessage == RemoteControlError.remoteControlUnavailable.recoverySuggestion)
    }

    @Test func supportedMoreKeyDispatchesCommand() async throws {
        let harness = RestorationHarness()
        await harness.connectSavedDevice()
        let menu = try #require(harness.state.moreKeyActions.first { $0.id == "menu" })

        await harness.viewModel.sendMoreKeyAction(menu)

        #expect(harness.client.sentCommands == [.syncMenu])
        #expect(harness.state.error == nil)
    }

    @Test func deviceSummaryOpensDeviceManagementInsteadOfSettings() async throws {
        let harness = RestorationHarness()
        await harness.connectSavedDevice()
        let savedDevice = try #require(harness.state.savedDevice)

        harness.viewModel.openDeviceManagement()

        #expect(!harness.state.isSettingsPresented)
        #expect(harness.state.isAutoConnectPresented)
        #expect(harness.state.autoConnect.screen == .connectedReady)
        #expect(harness.state.autoConnect.rememberedDevice == savedDevice)
        #expect(harness.state.autoConnect.selectedDevice?.displayName == savedDevice.displayName)
    }

    @Test func settingsOpenAndClosePreserveConnectedDevice() async throws {
        let harness = RestorationHarness()
        await harness.connectSavedDevice()
        let savedDevice = harness.state.savedDevice

        harness.viewModel.openSettings()
        #expect(harness.state.isSettingsPresented)
        harness.viewModel.closeSettings()

        #expect(!harness.state.isSettingsPresented)
        #expect(harness.state.savedDevice == savedDevice)
        try await waitUntil { harness.state.status == .connected }
        #expect(harness.state.status == .connected)
    }

    @Test func remotePreferenceTogglesMutateThroughPageViewModel() {
        let harness = RestorationHarness()

        harness.viewModel.setHapticFeedbackEnabled(false)
        harness.viewModel.setContinuousSendEnabled(false)
        harness.viewModel.setKeepScreenAwakeEnabled(false)

        #expect(!harness.state.remotePreferences.isHapticFeedbackEnabled)
        #expect(!harness.state.remotePreferences.isContinuousSendEnabled)
        #expect(!harness.state.remotePreferences.isKeepScreenAwakeEnabled)
    }

    @Test func aboutRowsRemainVisibleButDoNotNavigate() async {
        let harness = RestorationHarness()
        await harness.connectSavedDevice()
        harness.viewModel.openSettings()
        let snapshot = RestorationPageSnapshot(state: harness.state)

        for row in SettingsAboutRow.allCases {
            harness.viewModel.handleAboutRowTap(row)
            #expect(harness.state.isSettingsPresented)
            #expect(harness.state.presentedRemoteSurface == nil)
            #expect(!harness.state.isKeyboardInputActive)
        }

        snapshot.assertStillMatches(harness.state)
    }
}

@MainActor
private struct RestorationPageSnapshot {
    let status: ConnectionStatus
    let savedDevice: SonyDevice?
    let isSettingsPresented: Bool
    let presentedRemoteSurface: RemoteSurface?
    let isAutoConnectPresented: Bool

    init(state: RemotePageState) {
        status = state.status
        savedDevice = state.savedDevice
        isSettingsPresented = state.isSettingsPresented
        presentedRemoteSurface = state.presentedRemoteSurface
        isAutoConnectPresented = state.isAutoConnectPresented
    }

    func assertStillMatches(_ state: RemotePageState) {
        #expect(state.status == status)
        #expect(state.savedDevice == savedDevice)
        #expect(state.isSettingsPresented == isSettingsPresented)
        #expect(state.presentedRemoteSurface == presentedRemoteSurface)
        #expect(state.isAutoConnectPresented == isAutoConnectPresented)
    }
}

@MainActor
struct RestorationEmptyDiscoveryService: BRAVIADiscoveryServicing {
    func discover(timeout: TimeInterval) -> AsyncThrowingStream<BRAVIADiscoveryEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.finished([]))
            continuation.finish()
        }
    }
}
