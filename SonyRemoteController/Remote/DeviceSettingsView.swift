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
                    action: pageViewModel.openSettingsDeviceManagement
                )
            }

            sectionTitle("遥控器", y: 210)
            settingsGroup(rowCount: 1, y: 259) {
                SettingsToggleRow(
                    title: "按键震动反馈",
                    systemImage: "iphone.radiowaves.left.and.right",
                    isOn: pageState.remotePreferences.isHapticFeedbackEnabled,
                    action: { pageViewModel.setHapticFeedbackEnabled(!pageState.remotePreferences.isHapticFeedbackEnabled) }
                )
            }

            sectionTitle("关于", y: 338)
            settingsGroup(rowCount: 3, y: 439) {
                SettingsNavigationRow(title: "帮助与反馈", systemImage: "questionmark.circle", value: nil, tint: RemoteDesign.primaryBlue) {
                    pageViewModel.openSettingsRoute(.help)
                }
                SettingsNavigationRow(title: "隐私政策", systemImage: "hand.raised", value: nil, tint: RemoteDesign.primaryBlue) {
                    openURL(SettingsLinks.privacyPolicyURL)
                }
                SettingsNavigationRow(title: "关于应用", systemImage: "info.circle", value: nil, tint: RemoteDesign.primaryBlue) {
                    pageViewModel.openSettingsRoute(.about)
                }
            }
        }
        .clipped()
        .navigationDestination(item: settingsRouteBinding) { route in
            settingsDestination(route)
        }
    }

    private var settingsRouteBinding: Binding<SettingsRoute?> {
        Binding(
            get: { settingsState.presentedRoute },
            set: { route in
                if let route {
                    pageViewModel.openSettingsRoute(route)
                } else {
                    pageViewModel.closeSettingsRoute()
                }
            }
        )
    }

    @ViewBuilder
    private func settingsDestination(_ route: SettingsRoute) -> some View {
        switch route {
        case .deviceManagement:
            AutoConnectView(
                state: pageState.autoConnect,
                viewModel: pageViewModel.autoConnect,
                manualEntryState: settingsState,
                manualEntryViewModel: settingsViewModel,
                onManualEntrySave: pageViewModel.saveSettings,
                presentationMode: .settingsDetail,
                onDone: pageViewModel.closeSettingsRoute
            )
        case .help:
            HelpFeedbackView()
        case .about:
            AboutAppView()
        }
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
    static let supportEmailURL = URL(string: "mailto:xuanyue.pan@icloud.com?subject=BRAVIA%20Controller%20Feedback")!
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

private struct HelpFeedbackView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                InfoPageHeader(
                    systemImage: "questionmark.circle",
                    title: "帮助与反馈",
                    subtitle: "连接或控制异常时，可先检查以下项目。"
                )

                InfoSection(title: "连接检查", items: [
                    "确认 iPhone 和 BRAVIA 电视连接到同一个 Wi-Fi。",
                    "确认电视已开启 IP Control 或远程设备控制权限。",
                    "如果自动发现失败，可以返回设备管理页重新扫描。"
                ])

                InfoSection(title: "反馈", items: [
                    "反馈问题时请附上电视型号、iOS 版本、连接方式和复现步骤。"
                ])

                Button {
                    openURL(SettingsLinks.supportEmailURL)
                } label: {
                    Label("发送邮件反馈", systemImage: "envelope")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(RemoteDesign.primaryBlue, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(RemoteDesign.background.ignoresSafeArea())
        .navigationTitle("帮助与反馈")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AboutAppView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                InfoPageHeader(
                    systemImage: "tv",
                    title: appName,
                    subtitle: "用于在本地网络中发现并控制 Sony BRAVIA 电视。"
                )

                VStack(spacing: 0) {
                    InfoValueRow(title: "版本", value: versionText)
                    Divider().padding(.leading, 18)
                    InfoValueRow(title: "支持邮箱", value: "xuanyue.pan@icloud.com")
                    Divider().padding(.leading, 18)
                    InfoValueRow(title: "隐私政策", value: "GitHub Pages")
                }
                .background(RemoteDesign.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(RemoteDesign.border, lineWidth: 1)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(RemoteDesign.background.ignoresSafeArea())
        .navigationTitle("关于应用")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "BRAVIA Controller"
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct InfoPageHeader: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(RemoteDesign.primaryBlue)
                .frame(width: 56, height: 56)
                .background(RemoteDesign.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(RemoteDesign.border, lineWidth: 1)
                }

            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(RemoteDesign.text)

            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(RemoteDesign.secondaryText)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InfoSection: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
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

private struct InfoValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(RemoteDesign.text)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(RemoteDesign.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(height: 52)
        .padding(.horizontal, 18)
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
