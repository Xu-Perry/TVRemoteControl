import SwiftUI
import SonyRemoteCore

struct RemotePageView: View {
    let state: RemotePageState
    let viewModel: RemotePageViewModel

    var body: some View {
        NavigationStack {
            Group {
                if state.isAutoConnectPresented {
                    AutoConnectView(
                        state: state.autoConnect,
                        viewModel: viewModel.autoConnect
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
            .fullScreenCover(isPresented: keyboardBinding) {
                KeyboardInputView(
                    state: state,
                    viewModel: viewModel,
                    onDismiss: viewModel.dismissRemoteSurface
                )
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

    private var mainCanvas: some View {
        ZStack(alignment: .topLeading) {
            RemoteDesign.background

            DeviceSummaryCard(
                title: state.savedDevice?.displayName ?? state.connection.title,
                status: state.status.isConnected ? "已连接" : state.status.displayText,
                isConnected: state.status.isConnected,
                onTap: viewModel.openSettings
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
                    tint: RemoteDesign.primaryBlue
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

            Text("滑动以浏览更多按键")
                .font(.system(size: 13))
                .foregroundStyle(RemoteDesign.secondaryText)
                .frame(width: 170, height: 22)
                .position(x: 215, y: 767)

            HStack(spacing: 19) {
                Circle().fill(RemoteDesign.primaryBlue).frame(width: 8, height: 8)
                Circle().fill(Color(red: 0.85, green: 0.87, blue: 0.91)).frame(width: 8, height: 8)
            }
            .position(x: 215, y: 795)

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

    private var keyboardBinding: Binding<Bool> {
        Binding(
            get: { state.presentedRemoteSurface == .keyboardInput },
            set: { if !$0 { viewModel.dismissRemoteSurface() } }
        )
    }

    private var moreKeysBinding: Binding<Bool> {
        Binding(
            get: { state.presentedRemoteSurface == .moreKeysSheet },
            set: { if !$0 { viewModel.dismissRemoteSurface() } }
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
                .position(x: 106, y: 42)
            commandButton(.left, systemImage: "chevron.left")
                .position(x: 34, y: 106)
            commandButton(.right, systemImage: "chevron.right")
                .position(x: 178, y: 106)
            commandButton(.down, systemImage: "chevron.down")
                .position(x: 106, y: 174)

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
            Capsule()
                .fill(RemoteDesign.secondaryText.opacity(0.35))
                .frame(width: 60, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 14)

            Text("输入源")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(RemoteDesign.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
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

private struct KeyboardInputView: View {
    @Bindable var state: RemotePageState
    let viewModel: RemotePageViewModel
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                RemoteDesign.background.ignoresSafeArea()

                HStack(spacing: 14) {
                    TVThumbnail(width: 72, height: 42)
                    Text("● 正在输入到 \(state.savedDevice?.displayName ?? "BRAVIA")")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(RemoteDesign.connectedGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .frame(width: 390, height: 72)
                .background(RemoteDesign.surface, in: RoundedRectangle(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).stroke(RemoteDesign.border, lineWidth: 1) }
                .position(x: 215, y: 88)

                VStack(alignment: .leading, spacing: 10) {
                    Text("输入文字到电视")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(RemoteDesign.secondaryText)
                    TextEditor(text: $state.keyboardDraft.text)
                        .font(.system(size: 24, weight: .medium))
                        .scrollContentBackground(.hidden)
                        .frame(height: 110)
                        .onChange(of: state.keyboardDraft.text) { _, newValue in
                            if newValue.count > state.keyboardDraft.maxLength {
                                state.keyboardDraft.text = String(newValue.prefix(state.keyboardDraft.maxLength))
                            }
                        }
                    Text(state.keyboardDraft.characterCountText)
                        .font(.system(size: 14))
                        .foregroundStyle(RemoteDesign.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(18)
                .frame(width: 390, height: 206)
                .background(RemoteDesign.surface, in: RoundedRectangle(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).stroke(RemoteDesign.border, lineWidth: 1) }
                .position(x: 215, y: 234)

                HStack(spacing: 15) {
                    KeyboardActionButton(title: "发送到电视", systemImage: "paperplane", action: viewModel.sendKeyboardDraft)
                    KeyboardActionButton(title: "清空", systemImage: "xmark.circle", action: viewModel.clearKeyboardDraft)
                    KeyboardActionButton(title: "删除", systemImage: "delete.left", action: viewModel.deleteLastKeyboardCharacter)
                }
                .position(x: 215, y: 376)

                if let errorMessage = state.keyboardDraft.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(RemoteDesign.danger)
                        .frame(width: 360)
                        .position(x: 215, y: 432)
                }

                KeyboardMock()
                    .position(x: 215, y: 645)
            }
            .navigationTitle("键盘输入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("返回")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成", action: onDismiss)
                }
            }
        }
    }
}

private struct KeyboardActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(RemoteDesign.primaryBlue)
            .frame(width: 120, height: 56)
            .background(RemoteDesign.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(RemoteDesign.border, lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }
}

private struct KeyboardMock: View {
    private let rows: [[String]] = [
        "QWERTYUIOP".map { String($0) },
        "ASDFGHJKL".map { String($0) },
        ["⇧"] + "ZXCVBNM".map { String($0) } + ["⌫"],
        ["123", "space", "return"]
    ]

    var body: some View {
        VStack(spacing: 10) {
            Text("“SONY”        SONY'S        SONYING")
                .font(.system(size: 14))
                .foregroundStyle(RemoteDesign.text)
                .frame(width: 390, height: 36)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { key in
                        Text(key)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(RemoteDesign.text)
                            .frame(width: keyWidth(key), height: 46)
                            .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .frame(width: 430, height: 398)
        .background(Color(red: 0.82, green: 0.84, blue: 0.88))
    }

    private func keyWidth(_ key: String) -> CGFloat {
        switch key {
        case "123":
            92
        case "space":
            210
        case "return":
            88
        case "⇧", "⌫":
            50
        default:
            36
        }
    }
}

private struct MoreKeysSheet: View {
    let state: RemotePageState
    let viewModel: RemotePageViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("更多按键")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(RemoteDesign.text)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(RemoteDesign.secondaryText)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(54), spacing: 16), count: 3), spacing: 10) {
                ForEach(state.moreKeyActions.prefix(12)) { action in
                    moreKeyButton(action)
                        .frame(width: 54, height: 42)
                }
            }

            HStack(spacing: 16) {
                ForEach(state.moreKeyActions.dropFirst(12).prefix(4)) { action in
                    moreKeyButton(action)
                        .frame(width: 74, height: 58)
                }
            }

            if let playPause = state.moreKeyActions.first(where: { $0.id == "playpause" }) {
                moreKeyButton(playPause)
                    .frame(width: 170, height: 46)
            }

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
