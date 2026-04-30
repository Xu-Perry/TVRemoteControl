import SwiftUI
import SonyRemoteCore

struct RemotePageView: View {
    let state: RemotePageState
    let viewModel: RemotePageViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ConnectionHeaderView(
                        state: state.connection,
                        status: state.status,
                        onSettings: viewModel.openSettings
                    )

                    if let error = state.error {
                        ErrorBannerView(error: error, onOpenSettings: viewModel.openSettings)
                    }

                    if !state.canSendCommands {
                        Button {
                            viewModel.openSettings()
                        } label: {
                            Label("Connect a BRAVIA TV", systemImage: "tv")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("connectBraviaButton")
                    }

                    RemotePadView(
                        state: state.remotePad,
                        viewModel: viewModel.remotePad
                    )

                    UtilityControlsView(
                        state: state.remotePad,
                        viewModel: viewModel.remotePad
                    )
                }
                .padding()
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Sony Remote")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: Binding(
                get: { state.isSettingsPresented },
                set: { if !$0 { viewModel.closeSettings() } }
            )) {
                DeviceSettingsView(
                    state: state.settings,
                    viewModel: viewModel.settings,
                    onSave: {
                        viewModel.saveSettings()
                    }
                )
            }
        }
    }
}

private struct ConnectionHeaderView: View {
    let state: ConnectionHeaderState
    let status: ConnectionStatus
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: status.isConnected ? "tv.fill" : "tv")
                .font(.title2)
                .foregroundStyle(status.isConnected ? .green : .secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(state.title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(state.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.background.opacity(0.72), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("TV Settings")
            .accessibilityIdentifier("tvSettingsButton")
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

private struct ErrorBannerView: View {
    let error: RemoteControlError
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(error.title, systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
            Text(error.recoverySuggestion)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Open Settings", action: onOpenSettings)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("errorOpenSettingsButton")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("errorBanner")
    }
}

private struct RemotePadView: View {
    let state: RemotePadState
    let viewModel: RemotePadViewModel

    var body: some View {
        ZStack {
            commandButton(.up, systemImage: "chevron.up")
                .offset(y: -78)
            commandButton(.down, systemImage: "chevron.down")
                .offset(y: 78)
            commandButton(.left, systemImage: "chevron.left")
                .offset(x: -78)
            commandButton(.right, systemImage: "chevron.right")
                .offset(x: 78)
            commandButton(.confirm, title: "OK")
        }
        .frame(width: 236, height: 236)
        .frame(maxWidth: .infinity)
    }

    private func commandButton(_ command: RemoteCommand, systemImage: String? = nil, title: String? = nil) -> some View {
        Button {
            Task { await viewModel.send(command) }
        } label: {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.title2.weight(.semibold))
                } else {
                    Text(title ?? command.accessibilityLabel)
                        .font(.headline)
                }
            }
            .frame(width: 68, height: 68)
        }
        .buttonStyle(RemoteCircleButtonStyle(isEnabled: state.isEnabled && !state.isSendingCommand))
        .disabled(!state.isEnabled || state.isSendingCommand)
        .accessibilityLabel(command.accessibilityLabel)
        .accessibilityIdentifier("remoteCommand_\(command.rawValue)")
    }
}

private struct UtilityControlsView: View {
    let state: RemotePadState
    let viewModel: RemotePadViewModel

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                utilityButton(.back, systemImage: "chevron.backward")
                utilityButton(.home, systemImage: "house")
                utilityButton(.power, systemImage: "power")
            }

            HStack(spacing: 14) {
                utilityButton(.volumeDown, systemImage: "speaker.minus")
                utilityButton(.mute, systemImage: "speaker.slash")
                utilityButton(.volumeUp, systemImage: "speaker.plus")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func utilityButton(_ command: RemoteCommand, systemImage: String) -> some View {
        Button {
            Task { await viewModel.send(command) }
        } label: {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 72, height: 56)
        }
        .buttonStyle(RemoteCapsuleButtonStyle(
            isEnabled: state.isEnabled && !state.isSendingCommand,
            tint: command == .power ? .red : .accentColor
        ))
        .disabled(!state.isEnabled || state.isSendingCommand)
        .accessibilityLabel(command.accessibilityLabel)
        .accessibilityIdentifier("remoteCommand_\(command.rawValue)")
    }
}

private struct RemoteCircleButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? Color.white : Color.secondary)
            .background(
                Circle()
                    .fill(isEnabled ? Color.accentColor : Color.secondary.opacity(0.14))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(isEnabled ? 1 : 0.58)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

private struct RemoteCapsuleButtonStyle: ButtonStyle {
    let isEnabled: Bool
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? tint : Color.secondary)
            .background(
                Capsule()
                    .fill(isEnabled ? tint.opacity(0.14) : Color.secondary.opacity(0.12))
            )
            .overlay {
                Capsule()
                    .stroke(isEnabled ? tint.opacity(0.24) : Color.secondary.opacity(0.08), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(isEnabled ? 1 : 0.62)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    let state = RemotePageState()
    let viewModel = AppEnvironment.makeRemotePageViewModel(state: state)
    RemotePageView(state: state, viewModel: viewModel)
}
