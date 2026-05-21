import SwiftUI
import SonyRemoteCore

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
            .navigationDestination(isPresented: Binding(
                get: { state.isSettingsPresented },
                set: { if !$0 { viewModel.closeSettings() } }
            )) {
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
            let scale = proxy.size.width / RemoteDesign.canvasWidth

            ZStack {
                RemoteDesign.background
                    .ignoresSafeArea()

                mainCanvas
                    .frame(width: RemoteDesign.canvasWidth, height: RemoteDesign.canvasHeight)
                    .scaleEffect(scale, anchor: .top)
                    .offset(y: -20)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
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
                    deviceName: state.savedDevice?.displayName ?? "BRAVIA",
                    text: keyboardDraftTextBinding,
                    statusText: state.keyboardDraft.statusText,
                    status: state.keyboardDraft.status,
                    characterCountText: state.keyboardDraft.characterCountText,
                    errorMessage: state.keyboardDraft.errorMessage,
                    onSend: {
                        Task { await viewModel.sendKeyboardDraft() }
                    },
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
        .navigationTitle("BRAVIA Controller")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: viewModel.openSettings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("TV Settings")
                .accessibilityIdentifier("tvSettingsButton")
            }
        }
    }

    private var keyboardDraftTextBinding: Binding<String> {
        Binding(
            get: { state.keyboardDraft.text },
            set: { viewModel.updateKeyboardDraftText($0) }
        )
    }

    private var mainCanvas: some View {
        ZStack(alignment: .topLeading) {
            RemoteDesign.background

            DeviceSummaryCard(
                title: state.savedDevice?.displayName ?? state.connection.title,
                status: state.status.isConnected ? "已连接" : state.status.displayText,
                isConnected: state.status.isConnected,
                onTap: viewModel.openDeviceManagement
            )
            .position(x: 215, y: 102)

            VerticalControl(
                title: "音量",
                topSystemImage: "plus",
                bottomSystemImage: "minus",
                isEnabled: state.remotePad.isEnabled,
                topAction: { Task { await viewModel.remotePad.send(.volumeUp) } },
                bottomAction: { Task { await viewModel.remotePad.send(.volumeDown) } }
            )
            .position(x: 54, y: 300)

            VerticalControl(
                title: "频道",
                topSystemImage: "chevron.up",
                bottomSystemImage: "chevron.down",
                isEnabled: state.remotePad.isEnabled,
                topAction: { Task { await viewModel.remotePad.send(.channelUp) } },
                bottomAction: { Task { await viewModel.remotePad.send(.channelDown) } }
            )
            .position(x: 376, y: 300)

            DirectionPad(state: state.remotePad, viewModel: viewModel.remotePad)
                .position(x: 215, y: 299)

            HStack(spacing: 31) {
                RoundLabeledCommand(
                    title: "电源",
                    systemImage: "power",
                    command: .power,
                    state: state.remotePad,
                    viewModel: viewModel.remotePad,
                    tint: RemoteDesign.danger
                )
                RoundLabeledCommand(title: "主界面", systemImage: "house", command: .home, state: state.remotePad, viewModel: viewModel.remotePad)
                RoundLabeledCommand(title: "返回", systemImage: "arrow.uturn.backward", command: .back, state: state.remotePad, viewModel: viewModel.remotePad)
                RoundLabeledCommand(title: "静音", systemImage: "speaker.slash", command: .mute, state: state.remotePad, viewModel: viewModel.remotePad)
            }
            .position(x: 215, y: 537)

            HStack(spacing: 9) {
                ActionCard(title: "输入源", systemImage: "rectangle.arrowtriangle.2.inward", action: viewModel.openInputSourceSheet)
                ActionCard(title: "键盘输入", systemImage: "keyboard", action: viewModel.openKeyboardInput)
                ActionCard(title: "更多按键", systemImage: "ellipsis", action: viewModel.openMoreKeysSheet)
            }
            .position(x: 215, y: 685)

            if let error = state.error {
                ErrorBannerView(error: error, onOpenSettings: viewModel.openSettings)
                    .frame(width: 390)
                    .position(x: 215, y: 168)
            }
        }
        .clipped()
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
    static let canvasWidth: CGFloat = 430
    static let canvasHeight: CGFloat = 932
    static let background = Color(red: 0.969, green: 0.976, blue: 0.988)
    static let surface = Color.white
    static let border = Color(red: 0.898, green: 0.918, blue: 0.945)
    static let primaryBlue = Color(red: 0, green: 0.478, blue: 1)
    static let connectedGreen = Color(red: 0.098, green: 0.765, blue: 0.416)
    static let text = Color(red: 0.067, green: 0.094, blue: 0.153)
    static let secondaryText = Color(red: 0.42, green: 0.447, blue: 0.502)
    static let danger = Color(red: 1, green: 0.231, blue: 0.188)
}

struct DeviceSummaryCard: View {
    let title: String
    let status: String
    let isConnected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                TVThumbnail(width: 96, height: 60)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(RemoteDesign.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(isConnected ? RemoteDesign.connectedGreen : RemoteDesign.secondaryText)
                            .frame(width: 10, height: 10)
                        Text(status)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(isConnected ? RemoteDesign.connectedGreen : RemoteDesign.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(RemoteDesign.secondaryText)
            }
            .padding(.horizontal, 18)
            .frame(width: 400, height: 100)
            .background(RemoteDesign.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(RemoteDesign.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

struct TVThumbnail: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.08, green: 0.10, blue: 0.13))
                .frame(width: width, height: height * 0.82)
                .overlay {
                    Text("BRAVIA")
                        .font(.system(size: max(10, width * 0.13), weight: .bold))
                        .foregroundStyle(.white)
                }
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(red: 0.2, green: 0.22, blue: 0.26))
                .frame(width: width * 0.32, height: 4)
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }
}

private struct VerticalControl: View {
    let title: String
    let topSystemImage: String
    let bottomSystemImage: String
    let isEnabled: Bool
    let topAction: () -> Void
    let bottomAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: topAction) {
                Image(systemName: topSystemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 62, height: 73)
            }
            .disabled(!isEnabled)

            Divider().frame(width: 38)

            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(RemoteDesign.text)
                .frame(width: 62, height: 76)

            Divider().frame(width: 38)

            Button(action: bottomAction) {
                Image(systemName: bottomSystemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 62, height: 69)
            }
            .disabled(!isEnabled)
        }
        .foregroundStyle(isEnabled ? RemoteDesign.text : RemoteDesign.secondaryText.opacity(0.55))
        .frame(width: 62, height: 220)
        .background(RemoteDesign.surface, in: Capsule())
        .overlay { Capsule().stroke(RemoteDesign.border, lineWidth: 1) }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.62)
    }
}

private struct DirectionPad: View {
    let state: RemotePadState
    let viewModel: RemotePadViewModel

    var body: some View {
        ZStack {
            Circle()
                .fill(RemoteDesign.surface)
                .overlay { Circle().stroke(RemoteDesign.border, lineWidth: 1) }
                .frame(width: 212, height: 212)

            commandButton(.up, systemImage: "chevron.up")
                .position(x: 106, y: 34)
            commandButton(.left, systemImage: "chevron.left")
                .position(x: 34, y: 106)
            commandButton(.right, systemImage: "chevron.right")
                .position(x: 178, y: 106)
            commandButton(.down, systemImage: "chevron.down")
                .position(x: 106, y: 178)

            Button {
                Task { await viewModel.send(.confirm) }
            } label: {
                Text("OK")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(RemoteDesign.primaryBlue)
                    .frame(width: 88, height: 88)
                    .background(RemoteDesign.surface, in: Circle())
                    .overlay { Circle().stroke(RemoteDesign.border, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .disabled(!state.isEnabled)
            .opacity(state.isEnabled ? 1 : 0.62)
            .accessibilityLabel(RemoteCommand.confirm.accessibilityLabel)
        }
        .frame(width: 212, height: 212)
    }

    private func commandButton(_ command: RemoteCommand, systemImage: String) -> some View {
        Button {
            Task { await viewModel.send(command) }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(state.isEnabled ? RemoteDesign.text : RemoteDesign.secondaryText.opacity(0.55))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .disabled(!state.isEnabled)
        .accessibilityLabel(command.accessibilityLabel)
    }
}

private struct RoundLabeledCommand: View {
    let title: String
    let systemImage: String
    let command: RemoteCommand
    let state: RemotePadState
    let viewModel: RemotePadViewModel
    var tint = RemoteDesign.text

    var body: some View {
        VStack(spacing: 4) {
            Button {
                Task { await viewModel.send(command) }
            } label: {
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(state.isEnabled ? tint : RemoteDesign.secondaryText.opacity(0.55))
                    .frame(width: 70, height: 70)
                    .background(RemoteDesign.surface, in: Circle())
                    .overlay { Circle().stroke(RemoteDesign.border, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .disabled(!state.isEnabled)

            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(RemoteDesign.text)
                .frame(width: 74, height: 28)
        }
        .opacity(state.isEnabled ? 1 : 0.62)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(command.accessibilityLabel)
    }
}

private struct ActionCard: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(RemoteDesign.primaryBlue)
                    .frame(width: 32, height: 32)
                    .position(x: 34, y: 34)

                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(RemoteDesign.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: 86, height: 30, alignment: .leading)
                    .position(x: 61, y: 68)

                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(RemoteDesign.secondaryText)
                    .frame(width: 24, height: 24)
                    .position(x: 106, y: 46)
            }
            .frame(width: 124, height: 92)
            .background(RemoteDesign.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(RemoteDesign.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct ErrorBannerView: View {
    let error: RemoteControlError
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(RemoteDesign.danger)
            VStack(alignment: .leading, spacing: 3) {
                Text(error.title)
                    .font(.system(size: 14, weight: .semibold))
                Text(error.recoverySuggestion)
                    .font(.system(size: 12))
                    .foregroundStyle(RemoteDesign.secondaryText)
                    .lineLimit(2)
            }
            Spacer()
            Button("设置", action: onOpenSettings)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(12)
        .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(RemoteDesign.danger.opacity(0.25), lineWidth: 1) }
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
                            .foregroundStyle(option.command == nil ? RemoteDesign.secondaryText : RemoteDesign.primaryBlue)
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
                    .frame(height: 52)
                    .padding(.horizontal, 20)
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

            TextField("请输入文字", text: $text, axis: .vertical)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(RemoteDesign.text)
                .lineLimit(1...3)
                .focused($isTextFocused)
                .submitLabel(.send)
                .onSubmit(onSend)
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

            HStack(alignment: .top, spacing: 32) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(54), spacing: 10), count: 3), spacing: 12) {
                    ForEach(state.moreKeyActions.prefix(12)) { action in
                        moreKeyButton(action)
                            .frame(width: 54, height: 42)
                    }
                }
                .frame(width: 182)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(74), spacing: 22), count: 2), spacing: 18) {
                    ForEach(state.moreKeyActions.dropFirst(12)) { action in
                        moreKeyButton(action)
                            .frame(width: 74, height: 58)
                    }
                }
                .frame(width: 170)
            }
            .padding(.horizontal, 24)

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
                            .font(.system(size: action.symbolName == nil ? 18 : 13, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(action.isSupported ? RemoteDesign.text : RemoteDesign.secondaryText.opacity(0.6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RemoteDesign.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(RemoteDesign.border, lineWidth: 1) }
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
    state.savedDevice = SonyDevice(name: "BRAVIA XR-65A80L", host: "192.168.1.20", pskKey: "preview")
    state.status = .connected
    state.connection.title = "BRAVIA XR-65A80L"
    state.connection.subtitle = "Connected"
    state.remotePad.isEnabled = true
    state.isAutoConnectPresented = false
    return RemotePageView(state: state, viewModel: viewModel)
}
