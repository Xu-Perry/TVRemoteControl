import SwiftUI
import SonyRemoteCore

struct DeviceSettingsView: View {
    let pageState: RemotePageState
    @Bindable var settingsState: DeviceSettingsState
    let pageViewModel: RemotePageViewModel
    let settingsViewModel: DeviceSettingsViewModel
    let onClose: () -> Void
    let onSave: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / SettingsDesign.canvasWidth

            ZStack {
                RemoteDesign.background
                    .ignoresSafeArea()

                settingsCanvas
                    .frame(width: SettingsDesign.canvasWidth, height: SettingsDesign.canvasHeight)
                    .scaleEffect(scale, anchor: .top)
                    .offset(y: -20)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var settingsCanvas: some View {
        ZStack(alignment: .topLeading) {
            RemoteDesign.background

            sectionTitle("设备", y: 82)
            settingsGroup(rowCount: 1, y: 131) {
                SettingsNavigationRow(
                    title: "设备管理",
                    systemImage: "tv",
                    value: nil,
                    tint: RemoteDesign.primaryBlue,
                    action: pageViewModel.openDeviceManagement
                )
            }

            sectionTitle("遥控器", y: 210)
            settingsGroup(rowCount: 3, y: 311) {
                SettingsToggleRow(
                    title: "按键震动反馈",
                    systemImage: "iphone.radiowaves.left.and.right",
                    isOn: pageState.remotePreferences.isHapticFeedbackEnabled,
                    action: { pageViewModel.setHapticFeedbackEnabled(!pageState.remotePreferences.isHapticFeedbackEnabled) }
                )
                SettingsToggleRow(
                    title: "长按连续发送",
                    systemImage: "repeat",
                    isOn: pageState.remotePreferences.isContinuousSendEnabled,
                    action: { pageViewModel.setContinuousSendEnabled(!pageState.remotePreferences.isContinuousSendEnabled) }
                )
                SettingsToggleRow(
                    title: "保持屏幕常亮",
                    systemImage: "sun.max",
                    isOn: pageState.remotePreferences.isKeepScreenAwakeEnabled,
                    action: { pageViewModel.setKeepScreenAwakeEnabled(!pageState.remotePreferences.isKeepScreenAwakeEnabled) }
                )
            }

            sectionTitle("关于", y: 428)
            settingsGroup(rowCount: 3, y: 529) {
                SettingsNavigationRow(title: "帮助与反馈", systemImage: "questionmark.circle", value: nil, tint: RemoteDesign.primaryBlue) {
                    pageViewModel.handleAboutRowTap(.help)
                }
                SettingsNavigationRow(title: "隐私政策", systemImage: "hand.raised", value: nil, tint: RemoteDesign.primaryBlue) {
                    openURL(SettingsLinks.privacyPolicyURL)
                }
                SettingsNavigationRow(title: "关于应用", systemImage: "info.circle", value: nil, tint: RemoteDesign.primaryBlue) {
                    pageViewModel.handleAboutRowTap(.about)
                }
            }
        }
        .clipped()
    }

    private func sectionTitle(_ title: String, y: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(RemoteDesign.secondaryText)
            .frame(width: 100, height: 24, alignment: .leading)
            .position(x: 74, y: y)
    }

    private func settingsGroup<Content: View>(rowCount: Int, y: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0, content: content)
            .frame(width: 390, height: CGFloat(rowCount * 52 + 2))
            .background(RemoteDesign.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(RemoteDesign.border, lineWidth: 1)
            }
            .position(x: 215, y: y)
    }
}

private enum SettingsDesign {
    static let canvasWidth: CGFloat = 430
    static let canvasHeight: CGFloat = 932
}

private enum SettingsLinks {
    static let privacyPolicyURL = URL(string: "https://xu-perry.github.io/SonyController/privacy.html")!
}

private struct SettingsNavigationRow: View {
    let title: String
    let systemImage: String
    let value: String?
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsRowContent(title: title, systemImage: systemImage, value: value, tint: tint)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsRowContent: View {
    let title: String
    let systemImage: String
    let value: String?
    let tint: Color

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(RemoteDesign.text)

            Spacer()

            if let value {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundStyle(RemoteDesign.secondaryText)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(RemoteDesign.secondaryText)
        }
        .padding(.horizontal, 26)
        .frame(height: 52)
        .contentShape(Rectangle())
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let systemImage: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 18) {
                Image(systemName: systemImage)
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(RemoteDesign.primaryBlue)
                    .frame(width: 26, height: 26)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(RemoteDesign.text)

                Spacer()

                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? RemoteDesign.primaryBlue : RemoteDesign.border)
                        .frame(width: 48, height: 28)
                    Circle()
                        .fill(.white)
                        .frame(width: 24, height: 24)
                        .padding(2)
                }
                .frame(width: 48, height: 28)
            }
            .padding(.horizontal, 26)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "已开启" : "已关闭")
    }
}

#Preview("Settings") {
    let state = RemotePageState()
    let viewModel = AppEnvironment.makeRemotePageViewModel(state: state)
    state.savedDevice = SonyDevice(name: "BRAVIA XR-65A80L", host: "192.168.1.20", pskKey: "preview")
    state.status = .connected
    state.connection.title = "BRAVIA XR-65A80L"
    return NavigationStack {
        DeviceSettingsView(
            pageState: state,
            settingsState: state.settings,
            pageViewModel: viewModel,
            settingsViewModel: viewModel.settings,
            onClose: {},
            onSave: {}
        )
    }
}
