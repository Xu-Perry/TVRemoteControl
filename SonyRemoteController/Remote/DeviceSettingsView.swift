import SwiftUI
import SonyRemoteCore

struct DeviceSettingsView: View {
    @Bindable var state: DeviceSettingsState
    let viewModel: DeviceSettingsViewModel
    let onSave: () -> Void

    var body: some View {
        Form {
            Section("BRAVIA TV") {
                TextField("TV name", text: $state.tvName)
                    .textContentType(.name)
                    .accessibilityIdentifier("tvNameField")

                TextField("IP address", text: $state.ipAddress)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("ipAddressField")

                SecureField("Pre-Shared Key", text: $state.psk)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("pskField")
            }

            Section {
                Button {
                    Task { await viewModel.testConnection() }
                } label: {
                    HStack {
                        Text(state.isTestingConnection ? "Testing..." : "Test Connection")
                        if state.isTestingConnection {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(state.isTestingConnection)
                .accessibilityIdentifier("testConnectionButton")

                Button("Save") {
                    onSave()
                }
                .disabled(!state.canSave || state.isTestingConnection)
                .accessibilityIdentifier("saveDeviceButton")
            }

            if let successMessage = state.successMessage {
                Section {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityIdentifier("settingsSuccessMessage")
                }
            }

            if let error = state.error {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(error.title, systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                        Text(error.recoverySuggestion)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("settingsErrorMessage")
                }
            }

            Section("TV Requirements") {
                Text("TV and iPhone must be on the same local network.")
                Text("Enable IP Control on the BRAVIA TV.")
                Text("Enable Pre-Shared Key authentication and enter the same key here.")
                Text("Enable Remote Device Control on the TV.")
            }
        }
        .navigationTitle("TV Settings")
    }
}

#Preview {
    let state = RemotePageState()
    let viewModel = AppEnvironment.makeRemotePageViewModel(state: state)
    NavigationStack {
        DeviceSettingsView(state: state.settings, viewModel: viewModel.settings, onSave: {})
    }
}
