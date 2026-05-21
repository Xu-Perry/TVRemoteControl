import SwiftUI
import SonyRemoteCore

struct ConnectionDiagnosticsView: View {
    let state: ConnectionDiagnosticsState
    let viewModel: ConnectionDiagnosticsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                diagnosticsHeader

                Button {
                    viewModel.start()
                } label: {
                    Label(
                        state.isRunning ? "正在诊断" : "重新诊断",
                        systemImage: state.isRunning ? "waveform.path.ecg" : "arrow.clockwise"
                    )
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(RemoteDesign.primaryBlue, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(state.isRunning)
                .opacity(state.isRunning ? 0.65 : 1)

                VStack(spacing: 12) {
                    ForEach(state.steps) { step in
                        DiagnosticStepRow(step: step)
                    }
                }

                if !state.discoveredDevices.isEmpty {
                    DiagnosticDeviceSection(devices: state.discoveredDevices)
                }

                DiagnosticInstructionSection()
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(RemoteDesign.background.ignoresSafeArea())
        .navigationTitle("连接诊断")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.startIfNeeded()
        }
        .onDisappear {
            viewModel.cancel()
        }
    }

    private var diagnosticsHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(RemoteDesign.primaryBlue)
                .frame(width: 56, height: 56)
                .background(RemoteDesign.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(RemoteDesign.border, lineWidth: 1)
                }

            Text("连接诊断")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(RemoteDesign.text)

            Text(state.summary)
                .font(.system(size: 15))
                .foregroundStyle(RemoteDesign.secondaryText)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DiagnosticStepRow: View {
    let step: ConnectionDiagnosticStep

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 30, height: 30)
                .background(iconColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(step.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(RemoteDesign.text)

                    Text(statusText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(iconColor.opacity(0.1), in: Capsule())
                }

                Text(step.message)
                    .font(.system(size: 14))
                    .foregroundStyle(RemoteDesign.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RemoteDesign.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(RemoteDesign.border, lineWidth: 1)
        }
    }

    private var iconName: String {
        switch step.status {
        case .pending:
            "circle"
        case .running:
            "arrow.triangle.2.circlepath"
        case .passed:
            "checkmark"
        case .warning:
            "exclamationmark"
        case .failed:
            "xmark"
        }
    }

    private var iconColor: Color {
        switch step.status {
        case .pending:
            RemoteDesign.secondaryText
        case .running:
            RemoteDesign.primaryBlue
        case .passed:
            RemoteDesign.connectedGreen
        case .warning:
            Color(red: 0.965, green: 0.596, blue: 0.129)
        case .failed:
            RemoteDesign.danger
        }
    }

    private var statusText: String {
        switch step.status {
        case .pending:
            "待检查"
        case .running:
            "检查中"
        case .passed:
            "正常"
        case .warning:
            "需确认"
        case .failed:
            "异常"
        }
    }
}

private struct DiagnosticDeviceSection: View {
    let devices: [DiscoveredBRAVIADevice]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("发现的设备")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(RemoteDesign.text)

            VStack(spacing: 0) {
                ForEach(devices) { device in
                    HStack(spacing: 12) {
                        Image(systemName: "tv")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(RemoteDesign.primaryBlue)
                            .frame(width: 30, height: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.displayName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(RemoteDesign.text)
                            Text(device.host)
                                .font(.system(size: 13))
                                .foregroundStyle(RemoteDesign.secondaryText)
                        }

                        Spacer()
                    }
                    .frame(height: 56)
                    .padding(.horizontal, 16)

                    if device.id != devices.last?.id {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .background(RemoteDesign.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(RemoteDesign.border, lineWidth: 1)
            }
        }
    }
}

private struct DiagnosticInstructionSection: View {
    private let items = [
        "iPhone 和电视需要连接到同一个 Wi-Fi，且 App 需要在 iOS 本地网络权限中保持开启。",
        "电视需要开机，不能处于深度待机或断网状态。",
        "在电视设置中打开远程设备控制和 IP Control；如果使用预共享密钥连接，请确认认证方式和密钥一致。"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("电视端检查路径")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(RemoteDesign.text)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(RemoteDesign.primaryBlue)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)
                        Text(item)
                            .font(.system(size: 15))
                            .foregroundStyle(RemoteDesign.secondaryText)
                            .lineSpacing(3)
                    }
                }
            }
            .padding(16)
            .background(RemoteDesign.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(RemoteDesign.border, lineWidth: 1)
            }
        }
    }
}
