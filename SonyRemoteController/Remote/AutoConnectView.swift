import SwiftUI
import SonyRemoteCore

struct AutoConnectView: View {
    let state: AutoConnectState
    let viewModel: AutoConnectViewModel
    var presentationMode: AutoConnectPresentationMode = .primaryFlow
    var onDone: (() -> Void)?
    @State private var keyboardOverlap: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / AutoConnectDesign.canvasWidth

            ZStack {
                AutoConnectDesign.background
                    .ignoresSafeArea()

                designCanvas(scale: scale)
                    .frame(width: AutoConnectDesign.canvasWidth, height: AutoConnectDesign.canvasHeight)
                    .scaleEffect(scale, anchor: .top)
                    .offset(y: -20)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
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

            if state.isPinSheetPresented {
                pinSheetOverlay(keyboardOffset: KeyboardAvoidance.canvasOffset(for: keyboardOverlap, scale: scale))
            }
        }
        .clipped()
    }

    private var firstLaunchContent: some View {
        ZStack(alignment: .topLeading) {
            iconCircle(systemName: "tv", color: AutoConnectDesign.secondaryText, strokeColor: AutoConnectDesign.border)
                .position(x: 215, y: 308)

            centeredTitle("连接 BRAVIA 电视", y: 438)
            centeredSubtitle("首次使用前，请先扫描同一网络中的 Sony BRAVIA 电视。", y: 484)

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

    private var scanningContent: some View {
        ZStack(alignment: .topLeading) {
            pageTitle("正在扫描附近设备", subtitle: "正在搜索同一网络中的 BRAVIA 电视。")

            ZStack {
                Circle()
                    .fill(AutoConnectDesign.scanCircle)
                    .overlay(Circle().stroke(AutoConnectDesign.primaryBlue, lineWidth: 1))
                    .frame(width: 147, height: 146)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 42, weight: .regular))
                    .foregroundStyle(AutoConnectDesign.primaryBlue)
            }
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

    private var connectingContent: some View {
        ZStack(alignment: .topLeading) {
            let deviceName = state.selectedDevice?.displayName ?? "BRAVIA"
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
            let deviceName = state.selectedDevice?.displayName ?? state.rememberedDevice?.displayName ?? "BRAVIA"
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

    private func pinSheetOverlay(keyboardOffset: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {}

            VStack(spacing: 0) {
                Spacer()

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
                .background(
                    AutoConnectDesign.surface
                        .clipShape(RoundedCorner(radius: 24, corners: [.topLeft, .topRight]))
                        .ignoresSafeArea(edges: .bottom)
                )
                .offset(y: -keyboardOffset)
            }
        }
        .frame(width: AutoConnectDesign.canvasWidth, height: AutoConnectDesign.canvasHeight)
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
            pageTitle("未发现设备", subtitle: "没有找到同一网络中的 BRAVIA 电视。")

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

            Text("BRAVIA")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 16)
                .position(x: 48, y: 30)

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
            "BRAVIA Controller"
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

private enum AutoConnectDesign {
    static let canvasWidth: CGFloat = 430
    static let canvasHeight: CGFloat = 932
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

#Preview {
    let pageState = RemotePageState()
    let viewModel = AppEnvironment.makeRemotePageViewModel(state: pageState)
    AutoConnectView(state: pageState.autoConnect, viewModel: viewModel.autoConnect)
}
