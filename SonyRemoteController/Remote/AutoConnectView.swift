import SwiftUI
import SonyRemoteCore

struct AutoConnectView: View {
    let state: AutoConnectState
    let viewModel: AutoConnectViewModel
    let manualEntryState: DeviceSettingsState
    let manualEntryViewModel: DeviceSettingsViewModel
    let onManualEntrySave: () -> Void
    var presentationMode: AutoConnectPresentationMode = .primaryFlow
    var onDone: (() -> Void)?
    @State private var keyboardOverlap: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let scale = AutoConnectDesign.canvasScale(for: proxy.size)

            ZStack {
                AutoConnectDesign.background
                    .ignoresSafeArea()

                switch state.screen {
                case .firstLaunch:
                    firstLaunchResponsiveContent
                case .scanning:
                    scanningResponsiveContent
                case .devicesFound:
                    devicesFoundResponsiveContent
                case .connectedReady:
                    connectedResponsiveContent
                case .clearConfirmation:
                    connectedResponsiveContent
                    clearConnectionDialogResponsive
                default:
                    designCanvas(scale: scale)
                        .frame(width: AutoConnectDesign.canvasWidth, height: AutoConnectDesign.canvasHeight)
                        .scaleEffect(scale, anchor: .top)
                        .frame(width: AutoConnectDesign.canvasWidth * scale, height: AutoConnectDesign.canvasHeight * scale)
                        .offset(y: -AutoConnectDesign.canvasTopOffset * scale)
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                }

                if state.isPinSheetPresented {
                    pinSheetScreenOverlay(keyboardOffset: keyboardOverlap)
                }
            }
        }
        .navigationTitle(presentationMode.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if presentationMode.showsCloseButton && state.screen != .firstLaunch {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: closeOrCancel) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("取消")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            updateKeyboardOverlap(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardOverlap = 0
            }
        }
        .onChange(of: state.isPinSheetPresented) { _, isPresented in
            if !isPresented {
                keyboardOverlap = 0
            }
        }
        .navigationDestination(isPresented: manualEntryBinding) {
            ManualIPEntryView(
                state: manualEntryState,
                viewModel: manualEntryViewModel,
                onSave: onManualEntrySave
            )
        }
    }

    private var manualEntryBinding: Binding<Bool> {
        Binding(
            get: { state.isManualEntryPresented },
            set: { isPresented in
                if !isPresented {
                    viewModel.closeManualEntry()
                }
            }
        )
    }

    private func designCanvas(scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            AutoConnectDesign.background

            Group {
                switch state.screen {
                case .firstLaunch:
                    firstLaunchContent
                case .scanning:
                    scanningContent
                case .devicesFound:
                    devicesFoundContent
                case .connecting:
                    connectingContent
                case .connectedReady:
                    connectedContent
                case .clearConfirmation:
                    connectedContent
                    clearConnectionDialog
                case .noDevices:
                    noDevicesContent
                }
            }
            .offset(y: -88)

        }
        .clipped()
    }

    private var firstLaunchContent: some View {
        ZStack(alignment: .topLeading) {
            iconCircle(systemName: "tv", color: AutoConnectDesign.secondaryText, strokeColor: AutoConnectDesign.border)
                .position(x: 215, y: 308)

            centeredTitle("连接电视", y: 438)
            centeredSubtitle("首次使用前，请先扫描同一网络中的电视。", y: 484)

            primaryButton("扫描附近设备", systemImage: "magnifyingglass", action: viewModel.startScan)
                .position(x: 215, y: 673)

            secondaryButton("手动输入 IP", systemImage: "keyboard", action: viewModel.openManualEntry)
                .position(x: 215, y: 747)

            Text("连接后会自动记住设备，下次打开 App 可直接进入遥控器。")
                .font(.system(size: 14))
                .foregroundStyle(AutoConnectDesign.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(width: 314, height: 44)
                .position(x: 215, y: 842)
        }
    }

    private var firstLaunchResponsiveContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            VStack(spacing: 0) {
                iconCircle(systemName: "tv", color: AutoConnectDesign.secondaryText, strokeColor: AutoConnectDesign.border)

                Text("连接电视")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AutoConnectDesign.text)
                    .multilineTextAlignment(.center)
                    .padding(.top, 58)

                Text("首次使用前，请先扫描同一网络中的电视。")
                    .font(.system(size: 14))
                    .foregroundStyle(AutoConnectDesign.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 56)

            VStack(spacing: 0) {
                responsivePrimaryButton("扫描附近设备", systemImage: "magnifyingglass", action: viewModel.startScan)
                    .padding(.bottom, 20)

                responsiveSecondaryButton("手动输入 IP", systemImage: "keyboard", action: viewModel.openManualEntry)
                    .padding(.bottom, 50)

                Text("连接后会自动记住设备，下次打开 App 可直接进入遥控器。")
                    .font(.system(size: 14))
                    .foregroundStyle(AutoConnectDesign.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(maxWidth: 314)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 16)
        }
    }

    private var scanningContent: some View {
        ZStack(alignment: .topLeading) {
            pageTitle("正在扫描附近设备", subtitle: "正在搜索同一网络中的电视。")

            ScanningSearchIndicator()
                .position(x: 203.5, y: 347)

            Text("正在发现设备...")
                .font(.system(size: 16))
                .foregroundStyle(AutoConnectDesign.secondaryText)
                .frame(width: 217, height: 32)
                .position(x: 203.5, y: 480)

            secondaryButton("取消", systemImage: nil, width: 160, height: 50, action: viewModel.cancelScan)
                .position(x: 213, y: 827)
        }
    }

    private var scanningResponsiveContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 0) {
                secondaryHeader("正在扫描附近设备", subtitle: "正在搜索同一网络中的电视。")

                ScanningSearchIndicator()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 86)

                Text("正在发现设备...")
                    .font(.system(size: 16))
                    .foregroundStyle(AutoConnectDesign.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 34)

                secondaryButton("取消", systemImage: nil, width: 160, height: 50, action: viewModel.cancelScan)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 132)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 16)
        }
    }

    private var devicesFoundContent: some View {
        ZStack(alignment: .topLeading) {
            pageTitle("选择要连接的电视", subtitle: "发现 \(state.discoveredDevices.count) 台附近设备，选择一台开始连接。")

            ForEach(Array(state.discoveredDevices.prefix(5).enumerated()), id: \.element.id) { index, device in
                deviceRow(device, y: 262 + CGFloat(index * 100), height: 84, status: device.connectionReadiness.displayText)
            }

            secondaryButton("重新扫描", systemImage: "arrow.clockwise", width: 160, height: 50, action: viewModel.startScan)
                .position(x: 206, y: 826)

            if let error = state.connectionError {
                errorText(error)
                    .position(x: 215, y: 880)
            }
        }
    }

    private var devicesFoundResponsiveContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 0) {
                secondaryHeader(
                    "选择要连接的电视",
                    subtitle: "发现 \(state.discoveredDevices.count) 台附近设备，选择一台开始连接。"
                )

                VStack(spacing: 14) {
                    ForEach(state.discoveredDevices.prefix(5)) { device in
                        responsiveDeviceRow(device)
                    }
                }
                .padding(.top, 44)

                if let error = state.connectionError {
                    errorText(error)
                        .padding(.top, 12)
                }

                secondaryButton("重新扫描", systemImage: "arrow.clockwise", width: 160, height: 50, action: viewModel.startScan)
                    .frame(maxWidth: .infinity)
                    .padding(.top, state.discoveredDevices.count > 2 ? 56 : 236)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 16)
        }
    }

    private var connectingContent: some View {
        ZStack(alignment: .topLeading) {
            let deviceName = state.selectedDevice?.displayName ?? "电视"
            pageTitle("正在连接电视", subtitle: "已选择 \(deviceName)，正在建立连接。")

            if let device = state.selectedDevice {
                tvStatusCard(name: device.displayName, status: "正在连接...", statusColor: AutoConnectDesign.primaryBlue, y: 262, height: 84)
            }

            secondaryButton("取消连接", systemImage: nil, action: viewModel.cancelConnection)
                .position(x: 215, y: 829)
        }
    }

    private var connectedContent: some View {
        ZStack(alignment: .topLeading) {
            let deviceName = state.selectedDevice?.displayName ?? state.rememberedDevice?.displayName ?? "电视"
            pageTitle("已连接", subtitle: "\(deviceName) 已准备就绪。")

            tvStatusCard(
                name: deviceName,
                status: "已连接",
                statusColor: AutoConnectDesign.connectedGreen,
                y: 283,
                height: 126,
                showsCheckmark: true
            )

            secondaryButton(
                "清除当前连接",
                systemImage: nil,
                width: 346,
                height: 50,
                foreground: AutoConnectDesign.dangerRed,
                action: viewModel.showClearConfirmation
            )
            .position(x: 215, y: 767)

            primaryButton(connectedPrimaryActionTitle, systemImage: nil, action: connectedPrimaryAction)
                .position(x: 215, y: 839)
        }
    }

    private var connectedResponsiveContent: some View {
        let deviceName = state.selectedDevice?.displayName ?? state.rememberedDevice?.displayName ?? "电视"

        return VStack(spacing: 0) {
            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 0) {
                secondaryHeader("已连接", subtitle: "\(deviceName) 已准备就绪。")

                responsiveStatusCard(
                    name: deviceName,
                    status: "已连接",
                    statusColor: AutoConnectDesign.connectedGreen,
                    showsCheckmark: true
                )
                .padding(.top, 52)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 80)

            VStack(spacing: 16) {
                responsiveSecondaryButton(
                    "清除当前连接",
                    systemImage: nil,
                    foreground: AutoConnectDesign.dangerRed,
                    action: viewModel.showClearConfirmation
                )

                responsivePrimaryButton(connectedPrimaryActionTitle, systemImage: nil, action: connectedPrimaryAction)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 16)
        }
    }

    private func pinSheetScreenOverlay(keyboardOffset: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {}

            VStack(spacing: 0) {
                Spacer()
                pinSheetContent
                    .background(
                        AutoConnectDesign.surface
                            .clipShape(RoundedCorner(radius: 24, corners: [.topLeft, .topRight]))
                            .ignoresSafeArea(edges: .bottom)
                    )
                    .offset(y: -keyboardOffset)
            }
        }
    }

    private var pinSheetContent: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(AutoConnectDesign.secondaryText.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text("输入配对码")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AutoConnectDesign.text)
                .padding(.bottom, 8)

            Text("请输入电视屏幕上显示的 4 位数字")
                .font(.system(size: 14))
                .foregroundStyle(AutoConnectDesign.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)

            if state.isPairingInProgress {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.bottom, 8)
                Text("正在验证配对码...")
                    .font(.system(size: 14))
                    .foregroundStyle(AutoConnectDesign.secondaryText)
                    .padding(.bottom, 24)
            } else {
                pinInputField
                    .padding(.bottom, 24)
            }

            if let error = state.connectionError {
                Text(error.recoverySuggestion)
                    .font(.system(size: 13))
                    .foregroundStyle(AutoConnectDesign.dangerRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
            }

            if !state.isPairingInProgress {
                Button {
                    viewModel.submitPIN()
                } label: {
                    Text("确认配对")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .background(AutoConnectDesign.primaryBlue, in: RoundedRectangle(cornerRadius: 14))
                .disabled(state.pairingPIN.isEmpty)
                .opacity(state.pairingPIN.isEmpty ? 0.5 : 1)
                .padding(.horizontal, 32)
                .padding(.bottom, 12)
            }

            Button {
                viewModel.dismissPinSheet()
            } label: {
                Text("取消")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AutoConnectDesign.primaryBlue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .background(AutoConnectDesign.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AutoConnectDesign.border, lineWidth: 1)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private var pinInputField: some View {
        TextField("0000", text: Binding(
            get: { state.pairingPIN },
            set: { newValue in
                let filtered = newValue.filter { $0.isNumber }
                if filtered.count <= 4 {
                    state.pairingPIN = filtered
                }
            }
        ))
        .font(.system(size: 40, weight: .bold, design: .monospaced))
        .foregroundStyle(AutoConnectDesign.text)
        .multilineTextAlignment(.center)
        .keyboardType(.numberPad)
        .frame(width: 200, height: 56)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AutoConnectDesign.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(AutoConnectDesign.border, lineWidth: 1)
        }
    }

    private var noDevicesContent: some View {
        ZStack(alignment: .topLeading) {
            pageTitle("未发现设备", subtitle: "没有找到同一网络中的电视。")

            iconCircle(systemName: "magnifyingglass", color: AutoConnectDesign.secondaryText, strokeColor: AutoConnectDesign.border)
                .position(x: 215, y: 308)

            centeredTitle("没有发现附近设备", y: 438)
            centeredSubtitle("确认电视已开机，手机与电视在同一 Wi-Fi。", y: 484)

            primaryButton("重新扫描", systemImage: "arrow.clockwise", action: viewModel.startScan)
                .position(x: 215, y: 673)

            secondaryButton("手动输入 IP", systemImage: "keyboard", action: viewModel.openManualEntry)
                .position(x: 215, y: 747)

            VStack(alignment: .leading, spacing: 4) {
                Text("排查建议")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AutoConnectDesign.text)
                Text("打开电视的网络控制权限，或在电视设置中允许移动设备控制。")
                    .font(.system(size: 13))
                    .foregroundStyle(AutoConnectDesign.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 346, height: 58, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AutoConnectDesign.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AutoConnectDesign.border, lineWidth: 1)
            }
            .position(x: 215, y: 843)

            if let error = state.connectionError {
                errorText(error)
                    .position(x: 215, y: 900)
            }
        }
    }

    private var clearConnectionDialog: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.28)
                .frame(width: AutoConnectDesign.canvasWidth, height: AutoConnectDesign.canvasHeight)

            VStack(spacing: 0) {
                Image(systemName: "trash")
                    .font(.system(size: 38, weight: .regular))
                    .foregroundStyle(AutoConnectDesign.dangerRed)
                    .frame(width: 52, height: 52)
                    .padding(.top, 28)

                Text("清除当前连接？")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(AutoConnectDesign.text)
                    .padding(.top, 18)

                Text("清除后将忘记当前电视，下次需要重新扫描或手动输入 IP。")
                    .font(.system(size: 14))
                    .foregroundStyle(AutoConnectDesign.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(width: 286, height: 48)
                    .padding(.top, 8)

                HStack(spacing: 18) {
                    secondaryButton("取消", systemImage: nil, width: 128, height: 44, cornerRadius: 14, action: viewModel.cancelClearConnection)
                    primaryButton("清除连接", systemImage: nil, width: 152, height: 44, cornerRadius: 14, background: AutoConnectDesign.dangerRed, action: viewModel.clearRememberedConnection)
                }
                .padding(.top, 16)
            }
            .frame(width: 342, height: 275)
            .background(AutoConnectDesign.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AutoConnectDesign.border, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 22, y: 12)
            .position(x: 213, y: 463.5)
        }
    }

    private var clearConnectionDialogResponsive: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Image(systemName: "trash")
                    .font(.system(size: 38, weight: .regular))
                    .foregroundStyle(AutoConnectDesign.dangerRed)
                    .frame(width: 52, height: 52)
                    .padding(.top, 28)

                Text("清除当前连接？")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(AutoConnectDesign.text)
                    .padding(.top, 18)

                Text("清除后将忘记当前电视，下次需要重新扫描或手动输入 IP。")
                    .font(.system(size: 14))
                    .foregroundStyle(AutoConnectDesign.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(width: 286, height: 48)
                    .padding(.top, 8)

                HStack(spacing: 18) {
                    secondaryButton(
                        "取消",
                        systemImage: nil,
                        width: 128,
                        height: 44,
                        cornerRadius: 14,
                        action: viewModel.cancelClearConnection
                    )
                    primaryButton(
                        "清除连接",
                        systemImage: nil,
                        width: 152,
                        height: 44,
                        cornerRadius: 14,
                        background: AutoConnectDesign.dangerRed,
                        action: viewModel.clearRememberedConnection
                    )
                }
                .padding(.top, 16)
            }
            .frame(width: 342, height: 275)
            .background(AutoConnectDesign.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AutoConnectDesign.border, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 22, y: 12)
        }
    }

    private func pageTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AutoConnectDesign.text)
                .frame(width: 382, height: 34, alignment: .leading)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(AutoConnectDesign.secondaryText)
                .frame(width: 360, height: 24, alignment: .leading)
        }
        .position(x: 215, y: 152)
    }

    private func secondaryHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AutoConnectDesign.text)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(AutoConnectDesign.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func centeredTitle(_ title: String, y: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(AutoConnectDesign.text)
            .multilineTextAlignment(.center)
            .frame(width: 306, height: 32)
            .position(x: 215, y: y)
    }

    private func centeredSubtitle(_ subtitle: String, y: CGFloat) -> some View {
        Text(subtitle)
            .font(.system(size: 14))
            .foregroundStyle(AutoConnectDesign.secondaryText)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .frame(width: 290, height: 44)
            .position(x: 215, y: y)
    }

    private func iconCircle(systemName: String, color: Color, strokeColor: Color) -> some View {
        ZStack {
            Circle()
                .fill(AutoConnectDesign.emptyCircle)
                .overlay(Circle().stroke(strokeColor, lineWidth: 1))
                .frame(width: 156, height: 156)
            Image(systemName: systemName)
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(color)
        }
    }

    private func primaryButton(
        _ title: String,
        systemImage: String?,
        width: CGFloat = 346,
        height: CGFloat = 54,
        cornerRadius: CGFloat = 16,
        background: Color = AutoConnectDesign.primaryBlue,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 22, height: 22)
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                if systemImage != nil {
                    Spacer(minLength: 0)
                }
            }
            .padding(.leading, systemImage == nil ? 0 : 24)
            .frame(width: width, height: height)
            .foregroundStyle(.white)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .background(background, in: RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(background, lineWidth: 1)
        }
        .accessibilityIdentifier("autoConnectPrimaryAction")
    }

    private func responsivePrimaryButton(
        _ title: String,
        systemImage: String?,
        height: CGFloat = 54,
        cornerRadius: CGFloat = 16,
        background: Color = AutoConnectDesign.primaryBlue,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 22, height: 22)
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                if systemImage != nil {
                    Spacer(minLength: 0)
                }
            }
            .padding(.leading, systemImage == nil ? 0 : 24)
            .padding(.trailing, systemImage == nil ? 0 : 24)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .foregroundStyle(.white)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .background(background, in: RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(background, lineWidth: 1)
        }
        .accessibilityIdentifier("autoConnectPrimaryAction")
    }

    private func secondaryButton(
        _ title: String,
        systemImage: String?,
        width: CGFloat = 346,
        height: CGFloat = 54,
        cornerRadius: CGFloat = 16,
        foreground: Color = AutoConnectDesign.primaryBlue,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 22, height: 22)
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                if systemImage != nil {
                    Spacer(minLength: 0)
                }
            }
            .padding(.leading, systemImage == nil ? 0 : 24)
            .frame(width: width, height: height)
            .foregroundStyle(foreground)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .background(AutoConnectDesign.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(AutoConnectDesign.border, lineWidth: 1)
        }
    }

    private func responsiveSecondaryButton(
        _ title: String,
        systemImage: String?,
        height: CGFloat = 54,
        cornerRadius: CGFloat = 16,
        foreground: Color = AutoConnectDesign.primaryBlue,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 22, height: 22)
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                if systemImage != nil {
                    Spacer(minLength: 0)
                }
            }
            .padding(.leading, systemImage == nil ? 0 : 24)
            .padding(.trailing, systemImage == nil ? 0 : 24)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .foregroundStyle(foreground)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .background(AutoConnectDesign.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(AutoConnectDesign.border, lineWidth: 1)
        }
    }

    private func deviceRow(_ device: DiscoveredBRAVIADevice, y: CGFloat, height: CGFloat, status: String) -> some View {
        Button {
            viewModel.select(device)
        } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AutoConnectDesign.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AutoConnectDesign.border, lineWidth: 1)
                    }

                tvThumbnail
                    .frame(width: 96, height: 60)
                    .position(x: 68, y: height / 2)

                deviceName(device.displayName, width: 194)
                    .position(x: 251, y: height / 2 - 10)

                statusLabel(status, color: device.connectionReadiness == .connectable ? AutoConnectDesign.primaryBlue : AutoConnectDesign.secondaryText, dotSize: 8)
                    .position(x: 216, y: height / 2 + 17)

                Image(systemName: "chevron.right")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AutoConnectDesign.secondaryText)
                    .frame(width: 26, height: 26)
                    .position(x: 363, y: height / 2)
            }
            .frame(width: 386, height: height)
        }
        .buttonStyle(.plain)
        .position(x: 215, y: y)
    }

    private func responsiveDeviceRow(_ device: DiscoveredBRAVIADevice) -> some View {
        Button {
            viewModel.select(device)
        } label: {
            HStack(spacing: 16) {
                tvThumbnail
                    .frame(width: 96, height: 60)

                VStack(alignment: .leading, spacing: 8) {
                    Text(device.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AutoConnectDesign.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    statusLabel(
                        device.connectionReadiness.displayText,
                        color: device.connectionReadiness == .connectable ? AutoConnectDesign.primaryBlue : AutoConnectDesign.secondaryText,
                        dotSize: 8
                    )
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AutoConnectDesign.secondaryText)
                    .frame(width: 26, height: 26)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 84)
            .background(AutoConnectDesign.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AutoConnectDesign.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func responsiveStatusCard(
        name: String,
        status: String,
        statusColor: Color,
        showsCheckmark: Bool
    ) -> some View {
        HStack(spacing: 16) {
            tvThumbnail
                .frame(width: 96, height: 60)

            VStack(alignment: .leading, spacing: 8) {
                Text(name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AutoConnectDesign.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                statusLabel(status, color: statusColor, dotSize: showsCheckmark ? 10 : 8)
            }

            Spacer(minLength: 8)

            if showsCheckmark {
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AutoConnectDesign.connectedGreen)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 126)
        .background(AutoConnectDesign.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AutoConnectDesign.border, lineWidth: 1)
        }
    }

    private func tvStatusCard(
        name: String,
        status: String,
        statusColor: Color,
        y: CGFloat,
        height: CGFloat,
        showsCheckmark: Bool = false
    ) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(AutoConnectDesign.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AutoConnectDesign.border, lineWidth: 1)
                }

            tvThumbnail
                .frame(width: 96, height: 60)
                .position(x: 68, y: height / 2)

            deviceName(name, width: showsCheckmark ? 184 : 210)
                .position(x: showsCheckmark ? 258 : 259, y: height / 2 - 14)

            statusLabel(status, color: statusColor, dotSize: showsCheckmark ? 10 : 8)
                .position(x: showsCheckmark ? 221 : 221, y: height / 2 + 16)

            if showsCheckmark {
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AutoConnectDesign.connectedGreen)
                    .frame(width: 28, height: 28)
                    .position(x: 348, y: height / 2)
            }
        }
        .frame(width: 386, height: height)
        .position(x: 215, y: y)
    }

    private func deviceName(_ name: String, width: CGFloat) -> some View {
        Text(name)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(AutoConnectDesign.text)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(width: width, height: 26, alignment: .leading)
    }

    private func statusLabel(_ text: String, color: Color, dotSize: CGFloat) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: dotSize, height: dotSize)
            Text(text)
                .font(.system(size: dotSize == 10 ? 14 : 13))
                .foregroundStyle(color)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(width: 130, height: 24)
    }

    private var tvThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(red: 0.027, green: 0.043, blue: 0.086))
                .overlay {
                    ZStack {
                        DiagonalBand(color: Color(red: 0.126, green: 0.051, blue: 0.596), yOffset: -8, height: 15)
                        DiagonalBand(color: Color(red: 0.333, green: 0.149, blue: 0.945), yOffset: 2, height: 13)
                        DiagonalBand(color: Color(red: 0.051, green: 0.478, blue: 1), yOffset: 14, height: 9)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 1))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 1)
                        .stroke(AutoConnectDesign.text, lineWidth: 1)
                }
                .frame(width: 95, height: 51)
                .position(x: 48, y: 26)

            Rectangle()
                .fill(AutoConnectDesign.text)
                .frame(width: 10, height: 2)
                .position(x: 48, y: 54)

            Path { path in
                path.move(to: CGPoint(x: 18, y: 52))
                path.addLine(to: CGPoint(x: 9, y: 59))
                path.move(to: CGPoint(x: 78, y: 52))
                path.addLine(to: CGPoint(x: 87, y: 59))
            }
            .stroke(AutoConnectDesign.text, lineWidth: 2)
        }
        .frame(width: 96, height: 60)
    }

    private func errorText(_ error: RemoteControlError) -> some View {
        Text(error.recoverySuggestion)
            .font(.system(size: 13))
            .foregroundStyle(AutoConnectDesign.dangerRed)
            .frame(width: 346, alignment: .leading)
    }

    private func closeOrCancel() {
        switch state.screen {
        case .scanning:
            viewModel.cancelScan()
        case .connecting:
            viewModel.cancelConnection()
        case .connectedReady:
            viewModel.enterRemote()
        case .clearConfirmation:
            viewModel.cancelClearConnection()
        case .devicesFound, .noDevices:
            viewModel.showFirstLaunch()
        case .firstLaunch:
            break
        }
    }

    private var connectedPrimaryActionTitle: String {
        switch presentationMode {
        case .primaryFlow:
            "进入遥控器"
        case .settingsDetail:
            "完成"
        }
    }

    private func connectedPrimaryAction() {
        switch presentationMode {
        case .primaryFlow:
            viewModel.enterRemote()
        case .settingsDetail:
            onDone?()
        }
    }

    private func updateKeyboardOverlap(from notification: Notification) {
        guard state.isPinSheetPresented else {
            return
        }

        let overlap = KeyboardAvoidance.visibleKeyboardOverlap(from: notification)
        withAnimation(KeyboardAvoidance.animation(from: notification)) {
            keyboardOverlap = overlap
        }
    }
}

enum AutoConnectPresentationMode {
    case primaryFlow
    case settingsDetail

    var navigationTitle: String {
        switch self {
        case .primaryFlow:
            "TV Remote Control"
        case .settingsDetail:
            "设备管理"
        }
    }

    var showsCloseButton: Bool {
        switch self {
        case .primaryFlow:
            true
        case .settingsDetail:
            false
        }
    }
}

private struct ManualIPEntryView: View {
    @Bindable var state: DeviceSettingsState
    let viewModel: DeviceSettingsViewModel
    let onSave: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                InfoHeader(
                    systemImage: "network",
                    title: "手动连接电视",
                    subtitle: "输入电视的 IP 地址，先测试连接。如需 PSK 认证，系统会自动提示。"
                )

                VStack(spacing: 0) {
                    textFieldRow(
                        title: "IP 地址",
                        placeholder: "192.168.1.2",
                        text: $state.ipAddress,
                        keyboardType: .numbersAndPunctuation,
                        submitLabel: .done
                    )

                    if state.pskRequired == true {
                        Divider().padding(.leading, 18)
                        secureFieldRow(
                            title: "预共享密钥",
                            placeholder: "电视 IP Control 中配置的 PSK",
                            text: $state.psk
                        )
                    }
                }
                .background(AutoConnectDesign.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AutoConnectDesign.border, lineWidth: 1)
                }

                if let error = state.error {
                    MessageRow(text: error.recoverySuggestion, color: AutoConnectDesign.dangerRed)
                } else if let message = state.successMessage {
                    MessageRow(text: message, color: AutoConnectDesign.connectedGreen)
                }

                VStack(spacing: 12) {
                    Button {
                        Task { await viewModel.testConnection() }
                    } label: {
                        if state.isTestingConnection {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Label(testButtonTitle, systemImage: testButtonSymbol)
                        }
                    }
                    .buttonStyle(PrimaryManualButtonStyle())
                    .disabled(state.isTestingConnection)

                    Button(action: onSave) {
                        Text("保存并连接")
                    }
                    .buttonStyle(SecondaryManualButtonStyle(isEnabled: state.canSave && !state.isTestingConnection))
                    .disabled(!state.canSave || state.isTestingConnection)
                }

                ManualInfoSection(title: "连接前确认", items: [
                    "电视和 iPhone 已连接到同一个网络。",
                    "电视已开启 IP Control，并允许移动设备控制。",
                    "如电视需要 PSK 认证，会在测试连接后提示您输入。"
                ])
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(AutoConnectDesign.background.ignoresSafeArea())
        .navigationTitle("手动连接电视")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var testButtonTitle: String {
        state.pskRequired == true ? "验证 PSK" : "测试连接"
    }

    private var testButtonSymbol: String {
        state.pskRequired == true ? "lock.shield" : "antenna.radiowaves.left.and.right"
    }

    private func textFieldRow(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        submitLabel: SubmitLabel
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AutoConnectDesign.secondaryText)
            TextField(placeholder, text: text)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AutoConnectDesign.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .submitLabel(submitLabel)
        }
        .frame(height: 72)
        .padding(.horizontal, 18)
    }

    private func secureFieldRow(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AutoConnectDesign.secondaryText)
            SecureField(placeholder, text: text)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AutoConnectDesign.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
        }
        .frame(height: 72)
        .padding(.horizontal, 18)
    }
}

private struct InfoHeader: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(AutoConnectDesign.primaryBlue)
                .frame(width: 56, height: 56)
                .background(AutoConnectDesign.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AutoConnectDesign.border, lineWidth: 1)
                }

            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AutoConnectDesign.text)

            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(AutoConnectDesign.secondaryText)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MessageRow: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ManualInfoSection: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AutoConnectDesign.text)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(AutoConnectDesign.primaryBlue)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)
                        Text(item)
                            .font(.system(size: 15))
                            .foregroundStyle(AutoConnectDesign.secondaryText)
                            .lineSpacing(3)
                    }
                }
            }
            .padding(16)
            .background(AutoConnectDesign.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AutoConnectDesign.border, lineWidth: 1)
            }
        }
    }
}

private struct PrimaryManualButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AutoConnectDesign.primaryBlue, in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

private struct SecondaryManualButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(isEnabled ? AutoConnectDesign.primaryBlue : AutoConnectDesign.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AutoConnectDesign.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AutoConnectDesign.border, lineWidth: 1)
            }
            .opacity(configuration.isPressed && isEnabled ? 0.82 : 1)
    }
}

private enum AutoConnectDesign {
    static let canvasWidth: CGFloat = 430
    static let canvasHeight: CGFloat = 932
    static let canvasTopOffset: CGFloat = 20
    static let fittedContentHeight: CGFloat = 800
    static let background = Color(red: 0.969, green: 0.973, blue: 0.980)
    static let surface = Color.white
    static let border = Color(red: 0.875, green: 0.898, blue: 0.933)
    static let primaryBlue = Color(red: 0, green: 0.478, blue: 1)
    static let connectedGreen = Color(red: 0.125, green: 0.765, blue: 0.416)
    static let dangerRed = Color(red: 1, green: 0.231, blue: 0.188)
    static let text = Color(red: 0.067, green: 0.094, blue: 0.153)
    static let secondaryText = Color(red: 0.420, green: 0.447, blue: 0.502)
    static let emptyCircle = Color(red: 0.933, green: 0.949, blue: 0.969)
    static let scanCircle = Color(red: 0.918, green: 0.953, blue: 1)

    static func canvasScale(for size: CGSize) -> CGFloat {
        guard size.width > 0, size.height > 0 else {
            return 1
        }

        let widthScale = size.width / canvasWidth
        let heightScale = size.height / (fittedContentHeight - canvasTopOffset)
        return min(widthScale, heightScale)
    }
}

private struct RoundedCorner: Shape {
    let radius: CGFloat
    let corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

private struct DiagonalBand: View {
    let color: Color
    let yOffset: CGFloat
    let height: CGFloat

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 130, height: height)
            .rotationEffect(.degrees(-13))
            .offset(x: -4, y: yOffset)
    }
}

private struct ScanningSearchIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(AutoConnectDesign.primaryBlue.opacity(0.18), lineWidth: 10)
                .frame(width: 178, height: 178)
                .scaleEffect(isAnimating ? 1.08 : 0.82)
                .opacity(isAnimating ? 0 : 1)

            Circle()
                .stroke(AutoConnectDesign.primaryBlue.opacity(0.16), lineWidth: 8)
                .frame(width: 150, height: 150)
                .scaleEffect(isAnimating ? 1.14 : 0.88)
                .opacity(isAnimating ? 0.08 : 1)

            Circle()
                .fill(AutoConnectDesign.scanCircle)
                .overlay(Circle().stroke(AutoConnectDesign.primaryBlue, lineWidth: 1))
                .frame(width: 147, height: 146)

            Circle()
                .trim(from: 0.08, to: 0.32)
                .stroke(AutoConnectDesign.primaryBlue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 166, height: 166)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))

            Image(systemName: "magnifyingglass")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(AutoConnectDesign.primaryBlue)
                .scaleEffect(isAnimating ? 1.04 : 0.96)
        }
        .frame(width: 190, height: 190)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("正在搜索设备")
        .onAppear {
            withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    let pageState = RemotePageState()
    let viewModel = AppEnvironment.makeRemotePageViewModel(state: pageState)
    AutoConnectView(
        state: pageState.autoConnect,
        viewModel: viewModel.autoConnect,
        manualEntryState: pageState.settings,
        manualEntryViewModel: viewModel.settings,
        onManualEntrySave: viewModel.saveSettings
    )
}
