import SwiftUI
import TVRemoteCore

struct RemotePageView: View {
    let state: RemotePageState
    let viewModel: RemotePageViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if state.isAutoConnectPresented {
                    AutoConnectView(
                        state: state.autoConnect,
                        viewModel: viewModel.autoConnect,
                        manualEntryState: state.settings,
                        manualEntryViewModel: viewModel.settings,
                        onManualEntrySave: viewModel.saveSettings
                    )
                } else {
                    mainRemote
                }
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { state.isSettingsPresented },
                    set: { if !$0 { viewModel.closeSettings() } }
                )
            ) {
                DeviceSettingsView(
                    pageState: state,
                    settingsState: state.settings,
                    pageViewModel: viewModel,
                    settingsViewModel: viewModel.settings,
                    onClose: viewModel.closeSettings,
                    onSave: viewModel.saveSettings
                )
            }
        }
    }

    private var mainRemote: some View {
        GeometryReader { proxy in
            let metrics = RemoteLayoutMetrics(size: proxy.size)

            ZStack {
                RemoteDesign.remotePageBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    RemoteNavigationBar(
                        trailingInset: metrics.navigationHorizontalPadding,
                        onSettingsTap: viewModel.openSettings
                    )
                    .frame(maxWidth: metrics.screenMaxWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, metrics.screenHorizontalPadding)

                    ScrollView(showsIndicators: false) {
                        mainRemoteContent(metrics: metrics)
                            .frame(maxWidth: metrics.contentMaxWidth)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, metrics.contentHorizontalPadding)
                            .padding(.top, metrics.topPadding)
                            .padding(.bottom, metrics.bottomPadding)
                    }
                }
            }
            .sheet(isPresented: inputSourceBinding) {
                InputSourceSheet(
                    state: state,
                    viewModel: viewModel,
                    onDismiss: viewModel.dismissRemoteSurface
                )
                .presentationDetents([.height(372)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: moreKeysBinding) {
                MoreKeysSheet(
                    state: state,
                    viewModel: viewModel,
                    onDismiss: viewModel.dismissRemoteSurface
                )
                .presentationDetents([.height(372)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: keyboardInputBinding) {
                KeyboardInputSheet(
                    deviceName: state.savedDevice?.displayName ?? "TV",
                    text: keyboardDraftTextBinding,
                    statusText: state.keyboardDraft.statusText,
                    status: state.keyboardDraft.status,
                    characterCountText: state.keyboardDraft.characterCountText,
                    errorMessage: state.keyboardDraft.errorMessage,
                    onSend: viewModel.submitKeyboardDraft,
                    onDismiss: viewModel.closeKeyboardInput
                )
                .presentationDetents([.height(120)])
                .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            viewModel.refreshDeviceNameOnHomeAppear()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refreshDeviceNameOnHomeAppear()
            }
        }
        .navigationTitle("设置")
        .toolbar(.hidden, for: .navigationBar)
    }

    private var keyboardDraftTextBinding: Binding<String> {
        Binding(
            get: { state.keyboardDraft.text },
            set: { viewModel.updateKeyboardDraftText($0) }
        )
    }

    @ViewBuilder
    private func mainRemoteContent(metrics: RemoteLayoutMetrics) -> some View {
        mainRemoteStack(metrics: metrics)
    }

    private func mainRemoteStack(metrics: RemoteLayoutMetrics) -> some View {
        VStack(spacing: metrics.sectionSpacing) {
            DeviceSummaryCard(
                title: state.savedDevice?.displayName ?? state.connection.title,
                status: deviceStatusText,
                isConnected: state.status.isConnected,
                error: state.error,
                height: metrics.deviceCardHeight,
                onTap: viewModel.openDeviceManagement
            )
            .overlay(alignment: .trailing) {
                if state.error != nil {
                    retryButton
                        .padding(.trailing, metrics.deviceCardHorizontalPadding)
                }
            }

            primaryCommandsGrid(metrics: metrics)
            remoteControlsRow(metrics: metrics)
            remoteSurfaceActionsGrid(metrics: metrics)
        }
    }

    private var deviceStatusText: String {
        if let error = state.error, !state.status.isConnected {
            return error.title
        }
        if state.status.isConnected {
            if let host = state.savedDevice?.host, !host.isEmpty {
                return "已连接 • \(host)"
            }
            return "已连接"
        }
        return state.status.displayText
    }

    private var retryButton: some View {
        Button(action: viewModel.retryFromError) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(RemoteDesign.danger)
                .frame(width: 44, height: 44)
                .remoteGlassBackground(
                    Circle(),
                    tint: RemoteDesign.glassSurface,
                    isInteractive: true
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("重试连接")
    }

    private func remoteControlsRow(metrics: RemoteLayoutMetrics) -> some View {
        HStack(alignment: .center, spacing: metrics.sideControlSpacing) {
            VerticalControl(
                title: "音量",
                topSystemImage: "plus",
                middleSystemImage: "speaker.wave.2",
                bottomSystemImage: "minus",
                isEnabled: state.remotePad.isEnabled,
                width: metrics.sideControlWidth,
                height: metrics.directionPadSize,
                topAccessibilityLabel: "音量增加",
                bottomAccessibilityLabel: "音量减小",
                topAction: { Task { await viewModel.remotePad.send(.volumeUp) } },
                bottomAction: { Task { await viewModel.remotePad.send(.volumeDown) } }
            )

            DirectionPad(
                state: state.remotePad,
                viewModel: viewModel.remotePad,
                size: metrics.directionPadSize
            )

            VerticalControl(
                title: "频道",
                topSystemImage: "chevron.up",
                middleSystemImage: "number",
                bottomSystemImage: "chevron.down",
                isEnabled: state.remotePad.isEnabled,
                width: metrics.sideControlWidth,
                height: metrics.directionPadSize,
                topAccessibilityLabel: "频道增加",
                bottomAccessibilityLabel: "频道减小",
                topAction: { Task { await viewModel.remotePad.send(.channelUp) } },
                bottomAction: { Task { await viewModel.remotePad.send(.channelDown) } }
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: metrics.controlRowHeight)
    }

    private func primaryCommandsGrid(metrics: RemoteLayoutMetrics) -> some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: metrics.commandSpacing),
                count: 4
            ),
            spacing: metrics.commandSpacing
        ) {
            RoundLabeledCommand(
                title: "电源",
                systemImage: "power",
                command: .power,
                state: state.remotePad,
                viewModel: viewModel.remotePad,
                width: metrics.commandButtonWidth,
                height: metrics.commandButtonHeight,
                tint: RemoteDesign.danger
            )
            RoundLabeledCommand(
                title: "主界面",
                systemImage: "house",
                command: .home,
                state: state.remotePad,
                viewModel: viewModel.remotePad,
                width: metrics.commandButtonWidth,
                height: metrics.commandButtonHeight
            )
            RoundLabeledCommand(
                title: "返回",
                systemImage: "arrow.uturn.backward",
                command: .back,
                state: state.remotePad,
                viewModel: viewModel.remotePad,
                width: metrics.commandButtonWidth,
                height: metrics.commandButtonHeight
            )
            RoundLabeledCommand(
                title: "静音",
                systemImage: "speaker.slash",
                command: .mute,
                state: state.remotePad,
                viewModel: viewModel.remotePad,
                width: metrics.commandButtonWidth,
                height: metrics.commandButtonHeight
            )
        }
    }

    private func remoteSurfaceActionsGrid(metrics: RemoteLayoutMetrics) -> some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: metrics.actionSpacing),
                count: 3
            ),
            spacing: metrics.actionSpacing
        ) {
            ActionCard(
                title: "输入源",
                systemImage: "rectangle.arrowtriangle.2.inward",
                height: metrics.actionCardHeight,
                action: viewModel.openInputSourceSheet
            )
            ActionCard(
                title: "键盘",
                systemImage: "keyboard",
                height: metrics.actionCardHeight,
                action: viewModel.openKeyboardInput
            )
            ActionCard(
                title: "更多",
                systemImage: "ellipsis",
                height: metrics.actionCardHeight,
                action: viewModel.openMoreKeysSheet
            )
        }
    }

    private var inputSourceBinding: Binding<Bool> {
        Binding(
            get: { state.presentedRemoteSurface == .inputSourceSheet },
            set: { if !$0 { viewModel.dismissRemoteSurface() } }
        )
    }

    private var moreKeysBinding: Binding<Bool> {
        Binding(
            get: { state.presentedRemoteSurface == .moreKeysSheet },
            set: { if !$0 { viewModel.dismissRemoteSurface() } }
        )
    }

    private var keyboardInputBinding: Binding<Bool> {
        Binding(
            get: { state.isKeyboardInputActive },
            set: { if !$0 { viewModel.closeKeyboardInput() } }
        )
    }
}

enum RemoteDesign {
    static let background = Color(red: 0.949, green: 0.953, blue: 0.941)
    static let surface = Color.white
    static let border = Color.white.opacity(0.68)
    static let primaryBlue = Color(red: 0.369, green: 0.486, blue: 0.886)
    static let connectedGreen = Color(red: 0.098, green: 0.765, blue: 0.416)
    static let text = Color(red: 0.067, green: 0.067, blue: 0.067)
    static let secondaryText = Color(red: 0.4, green: 0.4, blue: 0.4)
    static let danger = Color(red: 0.851, green: 0.235, blue: 0.082)
    static let dangerSurface = Color(red: 0.898, green: 0.863, blue: 0.855)
    static let glassSurface = Color.white.opacity(0.82)
    static let glassHighlight = Color.white.opacity(0.95)
    static let glassShadow = Color(red: 0.42, green: 0.49, blue: 0.62).opacity(0.16)
    static let controlIcon = Color(red: 0.102, green: 0.145, blue: 0.224)

    static let remotePageBackground = LinearGradient(
        colors: [
            Color(red: 0.973, green: 0.988, blue: 1),
            Color(red: 0.941, green: 0.965, blue: 0.996),
            Color(red: 0.878, green: 0.914, blue: 0.973),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct RemoteLayoutMetrics {
    let screenHorizontalPadding: CGFloat
    let screenMaxWidth: CGFloat
    let navigationHorizontalPadding: CGFloat
    let contentHorizontalPadding: CGFloat
    let contentMaxWidth: CGFloat
    let scale: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let sectionSpacing: CGFloat
    let sideControlWidth: CGFloat
    let sideControlSpacing: CGFloat
    let directionPadSize: CGFloat
    let controlRowHeight: CGFloat
    let commandButtonWidth: CGFloat
    let commandButtonHeight: CGFloat
    let commandSpacing: CGFloat
    let actionSpacing: CGFloat
    let actionCardHeight: CGFloat
    let deviceCardHeight: CGFloat
    let deviceCardHorizontalPadding: CGFloat

    init(size: CGSize) {
        screenMaxWidth = 430
        let screenAvailableWidth = min(max(size.width, 320), screenMaxWidth)
        screenHorizontalPadding = max(0, (size.width - screenAvailableWidth) / 2)
        navigationHorizontalPadding = size.width < 360 ? 16 : 20

        let baseContentWidth: CGFloat = 386
        contentHorizontalPadding = size.width < 360 ? 16 : 22
        let availableWidth = max(size.width - contentHorizontalPadding * 2, 280)
        contentMaxWidth = min(availableWidth, baseContentWidth)
        scale = contentMaxWidth / baseContentWidth

        topPadding = 14 * scale
        bottomPadding = 40
        sectionSpacing = 52 * scale
        sideControlWidth = 64 * scale
        directionPadSize = 226 * scale
        controlRowHeight = 242 * scale
        let remainingControlWidth = contentMaxWidth - directionPadSize - sideControlWidth * 2
        sideControlSpacing = max(0, remainingControlWidth / 2)
        commandButtonWidth = 82 * scale
        commandButtonHeight = 70 * scale
        commandSpacing = max(0, (contentMaxWidth - commandButtonWidth * 4) / 3)
        let actionCardWidth = 122 * scale
        actionSpacing = max(0, (contentMaxWidth - actionCardWidth * 3) / 2)
        actionCardHeight = 52 * scale
        deviceCardHeight = 122 * scale
        deviceCardHorizontalPadding = 18 * scale
    }
}

extension View {
    @ViewBuilder
    fileprivate func remoteGlassBackground<S: Shape>(
        _ shape: S,
        tint: Color? = nil,
        isInteractive: Bool = false
    ) -> some View {
        self
            .background((tint ?? RemoteDesign.glassSurface), in: shape)
            .overlay(alignment: .topLeading) {
                shape
                    .stroke(RemoteDesign.glassHighlight, lineWidth: 0.8)
                    .blendMode(.screen)
            }
            .shadow(color: RemoteDesign.glassShadow, radius: isInteractive ? 18 : 14, x: 0, y: 10)
    }
}

private struct RemoteNavigationBar: View {
    let trailingInset: CGFloat
    let onSettingsTap: () -> Void

    var body: some View {
        ZStack {
            Text("你的专属遥控器")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RemoteDesign.text)
                .lineLimit(1)

            Button(action: onSettingsTap) {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RemoteDesign.controlIcon)
                    .frame(width: 46, height: 46)
                    .remoteGlassBackground(
                        Circle(),
                        tint: RemoteDesign.glassSurface,
                        isInteractive: true
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("TV Settings")
            .accessibilityIdentifier("tvSettingsButton")
            .padding(.trailing, trailingInset)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: 58)
    }
}

struct DeviceSummaryCard: View {
    let title: String
    let status: String
    let isConnected: Bool
    let error: RemoteControlError?
    let height: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                TVThumbnail(size: thumbnailSize)

                VStack(alignment: .leading, spacing: 7) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(RemoteDesign.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(
                                isConnected
                                    ? RemoteDesign.connectedGreen : RemoteDesign.secondaryText
                            )
                            .frame(width: 10, height: 10)
                        Text(status)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(statusColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    if let error {
                        Text(error.recoverySuggestion)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(RemoteDesign.danger)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.trailing, error == nil ? 0 : 56)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
            .remoteGlassBackground(
                RoundedRectangle(cornerRadius: 24, style: .continuous),
                tint: RemoteDesign.glassSurface,
                isInteractive: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var thumbnailSize: CGFloat {
        max(62, min(82, height - 40))
    }

    private var statusColor: Color {
        if error != nil, !isConnected {
            return RemoteDesign.danger
        }
        return isConnected ? RemoteDesign.connectedGreen : RemoteDesign.secondaryText
    }
}

struct TVThumbnail: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.82))
                .overlay {
                    RoundedRectangle(cornerRadius: 16).stroke(
                        RemoteDesign.glassHighlight, lineWidth: 0.8)
                }

            Image(systemName: "tv")
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(RemoteDesign.primaryBlue)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct VerticalControl: View {
    let title: String
    let topSystemImage: String
    let middleSystemImage: String
    let bottomSystemImage: String
    let isEnabled: Bool
    let width: CGFloat
    let height: CGFloat
    let topAccessibilityLabel: String
    let bottomAccessibilityLabel: String
    let topAction: () -> Void
    let bottomAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: topAction) {
                Image(systemName: topSystemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: height * 0.28)
            }
            .disabled(!isEnabled)
            .accessibilityLabel(topAccessibilityLabel)

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                Image(systemName: middleSystemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            Button(action: bottomAction) {
                Image(systemName: bottomSystemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: height * 0.28)
            }
            .disabled(!isEnabled)
            .accessibilityLabel(bottomAccessibilityLabel)
        }
        .foregroundStyle(
            isEnabled ? RemoteDesign.controlIcon : RemoteDesign.secondaryText.opacity(0.55)
        )
        .frame(width: width, height: height)
        .remoteGlassBackground(Capsule(), tint: RemoteDesign.glassSurface)
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.62)
    }
}

private struct DirectionPad: View {
    let state: RemotePadState
    let viewModel: RemotePadViewModel
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(.clear)
                .frame(width: size, height: size)
                .remoteGlassBackground(Circle(), tint: RemoteDesign.glassSurface)

            commandButton(.up, systemImage: "chevron.up")
                .position(x: size * 0.5, y: size * 0.195)
            commandButton(.left, systemImage: "chevron.left")
                .position(x: size * 0.195, y: size * 0.5)
            commandButton(.right, systemImage: "chevron.right")
                .position(x: size * 0.805, y: size * 0.5)
            commandButton(.down, systemImage: "chevron.down")
                .position(x: size * 0.5, y: size * 0.805)

            Button {
                Task { await viewModel.send(.confirm) }
            } label: {
                Text("OK")
                    .font(.system(size: max(13, size * 0.066), weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: centerButtonSize, height: centerButtonSize)
                    .background(RemoteDesign.controlIcon, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!state.isEnabled)
            .opacity(state.isEnabled ? 1 : 0.62)
            .accessibilityLabel(RemoteCommand.confirm.accessibilityLabel)
        }
        .frame(width: size, height: size)
    }

    private func commandButton(_ command: RemoteCommand, systemImage: String) -> some View {
        Button {
            Task { await viewModel.send(command) }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(
                    state.isEnabled
                        ? RemoteDesign.controlIcon : RemoteDesign.secondaryText.opacity(0.55)
                )
                .frame(
                    width: directionButtonWidth(for: command),
                    height: directionButtonHeight(for: command)
                )
                .remoteGlassBackground(
                    RoundedRectangle(cornerRadius: 24, style: .continuous),
                    tint: RemoteDesign.glassSurface,
                    isInteractive: state.isEnabled
                )
        }
        .buttonStyle(.plain)
        .disabled(!state.isEnabled)
        .accessibilityLabel(command.accessibilityLabel)
    }

    private var directionButtonSize: CGFloat {
        max(44, size * 0.23)
    }

    private var centerButtonSize: CGFloat {
        max(62, size * 0.31)
    }

    private func directionButtonWidth(for command: RemoteCommand) -> CGFloat {
        switch command {
        case .up, .down:
            max(52, size * 0.257)
        default:
            directionButtonSize
        }
    }

    private func directionButtonHeight(for command: RemoteCommand) -> CGFloat {
        switch command {
        case .left, .right:
            max(52, size * 0.257)
        default:
            directionButtonSize
        }
    }
}

private struct RoundLabeledCommand: View {
    let title: String
    let systemImage: String
    let command: RemoteCommand
    let state: RemotePadState
    let viewModel: RemotePadViewModel
    let width: CGFloat
    let height: CGFloat
    var tint = RemoteDesign.text

    var body: some View {
        Button {
            Task { await viewModel.send(command) }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        state.isEnabled ? tint : RemoteDesign.secondaryText.opacity(0.55)
                    )
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(
                        state.isEnabled ? tint : RemoteDesign.secondaryText.opacity(0.55)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: width, height: height)
            .remoteGlassBackground(
                RoundedRectangle(cornerRadius: max(18, height * 0.31), style: .continuous),
                tint: command == .power ? RemoteDesign.dangerSurface : RemoteDesign.glassSurface,
                isInteractive: state.isEnabled
            )
        }
        .buttonStyle(.plain)
        .disabled(!state.isEnabled)
        .opacity(state.isEnabled ? 1 : 0.62)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(command.accessibilityLabel)
    }
}

private struct ActionCard: View {
    let title: String
    let systemImage: String
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RemoteDesign.controlIcon)
                    .frame(width: 20, height: 20)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RemoteDesign.controlIcon)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: height)
            .remoteGlassBackground(
                Capsule(),
                tint: RemoteDesign.glassSurface,
                isInteractive: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct ErrorBannerView: View {
    let error: RemoteControlError
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(RemoteDesign.danger)
                .font(.system(size: 18, weight: .semibold))
            VStack(alignment: .leading, spacing: 3) {
                Text(error.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RemoteDesign.text)
                Text(error.recoverySuggestion)
                    .font(.system(size: 12))
                    .foregroundStyle(RemoteDesign.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(action: onRetry) {
                Label("重试", systemImage: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .remoteGlassBackground(
                        Capsule(), tint: RemoteDesign.primaryBlue.opacity(0.12), isInteractive: true
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(RemoteDesign.primaryBlue)
            .accessibilityLabel("重试连接")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 56)
        .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14).stroke(
                RemoteDesign.danger.opacity(0.25), lineWidth: 1)
        }
    }
}

private struct InputSourceSheet: View {
    let state: RemotePageState
    let viewModel: RemotePageViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("输入源")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(RemoteDesign.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 34)
                .padding(.bottom, 10)

            ForEach(state.inputSources) { option in
                Button {
                    Task { await viewModel.selectInputSource(option) }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: option.symbolName)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(
                                option.command == nil
                                    ? RemoteDesign.secondaryText : RemoteDesign.primaryBlue
                            )
                            .frame(width: 28)
                        Text(option.title)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(RemoteDesign.text)
                        Spacer()
                        if option.isSelected {
                            Image(systemName: "checkmark")
                                .foregroundStyle(RemoteDesign.primaryBlue)
                                .font(.system(size: 18, weight: .bold))
                        }
                        Image(systemName: "chevron.right")
                            .foregroundStyle(RemoteDesign.secondaryText)
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(option.command == nil)

                if option.id != state.inputSources.last?.id {
                    Divider().padding(.leading, 60)
                }
            }

            Spacer()
        }
        .background(RemoteDesign.background)
    }
}

private struct KeyboardInputSheet: View {
    let deviceName: String
    @Binding var text: String
    let statusText: String
    let status: KeyboardDraftStatus
    let characterCountText: String
    let errorMessage: String?
    let onSend: () -> Void
    let onDismiss: () -> Void
    @FocusState private var isTextFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "keyboard")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RemoteDesign.primaryBlue)
                Text("输入到 \(deviceName)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RemoteDesign.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(footerText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(footerColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            TextField("请输入文字", text: $text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(RemoteDesign.text)
                .lineLimit(1)
                .focused($isTextFocused)
                .submitLabel(.send)
                .onSubmit {
                    guard status != .sending else { return }
                    onSend()
                }
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                .accessibilityIdentifier("keyboardInputField")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RemoteDesign.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(RemoteDesign.border)
                .frame(height: 1)
        }
        .onAppear {
            isTextFocused = true
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "keyboard.chevron.compact.down")
                }
                .foregroundStyle(RemoteDesign.secondaryText)
                .accessibilityLabel("收起键盘输入")
            }
        }
    }

    private var footerText: String {
        if let errorMessage {
            errorMessage
        } else if status == .empty {
            characterCountText
        } else {
            "\(statusText) · \(characterCountText)"
        }
    }

    private var footerColor: Color {
        switch status {
        case .empty:
            RemoteDesign.secondaryText
        case .editing, .sending:
            RemoteDesign.primaryBlue
        case .sent:
            RemoteDesign.connectedGreen
        case .failed:
            RemoteDesign.danger
        }
    }
}

private struct MoreKeysSheet: View {
    let state: RemotePageState
    let viewModel: RemotePageViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Text("更多按键")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(RemoteDesign.text)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(RemoteDesign.secondaryText)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.top, 34)

            HStack(alignment: .top, spacing: 18) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                    spacing: 12
                ) {
                    ForEach(state.moreKeyActions.prefix(12)) { action in
                        moreKeyButton(action)
                            .frame(height: 42)
                    }
                }
                .frame(maxWidth: .infinity)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2),
                    spacing: 18
                ) {
                    ForEach(state.moreKeyActions.dropFirst(12)) { action in
                        moreKeyButton(action)
                            .frame(height: 58)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 432)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .background(RemoteDesign.background)
    }

    private func moreKeyButton(_ action: MoreKeyAction) -> some View {
        Group {
            if action.title.isEmpty {
                Color.clear
            } else {
                Button {
                    Task { await viewModel.sendMoreKeyAction(action) }
                } label: {
                    VStack(spacing: 4) {
                        if let symbolName = action.symbolName {
                            Image(systemName: symbolName)
                                .font(.system(size: 20, weight: .semibold))
                        }
                        Text(action.title)
                            .font(
                                .system(size: action.symbolName == nil ? 18 : 13, weight: .medium)
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(
                        action.isSupported
                            ? RemoteDesign.text : RemoteDesign.secondaryText.opacity(0.6)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RemoteDesign.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12).stroke(RemoteDesign.border, lineWidth: 1)
                    }
                    .opacity(action.isSupported && state.remotePad.isEnabled ? 1 : 0.56)
                }
                .buttonStyle(.plain)
                .disabled(!action.isSupported || !state.remotePad.isEnabled)
                .accessibilityLabel(action.title)
            }
        }
    }
}

#Preview("Connected Remote") {
    let state = RemotePageState()
    let viewModel = AppEnvironment.makeRemotePageViewModel(state: state)
    state.savedDevice = TVDevice(name: "Living Room TV", host: "192.168.1.20", pskKey: "preview")
    state.status = .connected
    state.connection.title = "Living Room TV"
    state.connection.subtitle = "Connected"
    state.remotePad.isEnabled = true
    state.isAutoConnectPresented = false
    return RemotePageView(state: state, viewModel: viewModel)
}
