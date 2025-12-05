//
//  ContentView.swift
//  loopRemider
//
//  Created by 数源 on 2025/12/5.
//

import SwiftUI
import UserNotifications
import Combine

// MARK: - App Settings

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let isRunning = "isRunning"
        static let intervalSeconds = "intervalSeconds"
        static let notifTitle = "notifTitle"
        static let notifBody = "notifBody"
        static let notifEmoji = "notifEmoji"
        static let lastFire = "lastFire"
        static let notificationMode = "notificationMode"
        static let overlayPosition = "overlayPosition"
        static let overlayColor = "overlayColor"
        static let overlayOpacity = "overlayOpacity"
        static let overlayFadeDelay = "overlayFadeDelay"
        static let overlayFadeStartDelay = "overlayFadeStartDelay"
        static let overlayFadeDuration = "overlayFadeDuration"
    }

    private let defaults = UserDefaults.standard
    private var cancellables: Set<AnyCancellable> = []

    // Observable values - 基本设置
    @Published var isRunning: Bool
    @Published var intervalSeconds: Double
    @Published var notificationMode: NotificationMode

    @Published var notifTitle: String
    @Published var notifBody: String
    @Published var notifEmoji: String

    @Published var lastFireEpoch: Double
    
    // Observable values - 通知样式
    @Published var overlayPosition: OverlayPosition
    @Published var overlayColor: OverlayColor
    @Published var overlayOpacity: Double
    @Published var overlayFadeStartDelay: Double // 开始淡化的延迟时间（秒），默认2秒
    @Published var overlayFadeDuration: Double // 淡化持续时间（秒），-1表示自动
    
    enum NotificationMode: String, CaseIterable {
        case system = "系统通知"
        case overlay = "屏幕遮罩"
    }
    
    enum OverlayPosition: String, CaseIterable {
        case topRight = "右上角"
        case topLeft = "左上角"
        case topCenter = "顶部居中"
        case center = "屏幕中央"
    }
    
    enum OverlayColor: String, CaseIterable {
        case black = "黑色"
        case blue = "蓝色"
        case purple = "紫色"
        case green = "绿色"
        case orange = "橙色"
    }

    init() {
        // Load - 基本设置
        self.isRunning = defaults.object(forKey: Keys.isRunning) as? Bool ?? false
        self.intervalSeconds = defaults.object(forKey: Keys.intervalSeconds) as? Double ?? 1800 // 默认30分钟
        self.notifTitle = defaults.string(forKey: Keys.notifTitle) ?? "提醒"
        self.notifBody = defaults.string(forKey: Keys.notifBody) ?? "起来活动一下～"
        self.notifEmoji = defaults.string(forKey: Keys.notifEmoji) ?? "⏰"
        self.lastFireEpoch = defaults.object(forKey: Keys.lastFire) as? Double ?? 0
        
        let modeRawValue = defaults.string(forKey: Keys.notificationMode) ?? NotificationMode.system.rawValue
        self.notificationMode = NotificationMode(rawValue: modeRawValue) ?? .system
        
        // Load - 通知样式
        let positionRawValue = defaults.string(forKey: Keys.overlayPosition) ?? OverlayPosition.topRight.rawValue
        self.overlayPosition = OverlayPosition(rawValue: positionRawValue) ?? .topRight
        
        let colorRawValue = defaults.string(forKey: Keys.overlayColor) ?? OverlayColor.black.rawValue
        self.overlayColor = OverlayColor(rawValue: colorRawValue) ?? .black
        
        self.overlayOpacity = defaults.object(forKey: Keys.overlayOpacity) as? Double ?? 0.85
        self.overlayFadeStartDelay = defaults.object(forKey: Keys.overlayFadeStartDelay) as? Double ?? 2.0 // 默认2秒后开始淡化
        self.overlayFadeDuration = defaults.object(forKey: Keys.overlayFadeDuration) as? Double ?? -1 // -1 = 自动

        // Persist changes - 基本设置
        $isRunning.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.isRunning) }.store(in: &cancellables)
        $intervalSeconds.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.intervalSeconds) }.store(in: &cancellables)
        $notifTitle.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.notifTitle) }.store(in: &cancellables)
        $notifBody.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.notifBody) }.store(in: &cancellables)
        $notifEmoji.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.notifEmoji) }.store(in: &cancellables)
        $lastFireEpoch.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.lastFire) }.store(in: &cancellables)
        $notificationMode.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.notificationMode) }.store(in: &cancellables)
        
        // Persist changes - 通知样式
        $overlayPosition.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.overlayPosition) }.store(in: &cancellables)
        $overlayColor.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.overlayColor) }.store(in: &cancellables)
        $overlayOpacity.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayOpacity) }.store(in: &cancellables)
        $overlayFadeStartDelay.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayFadeStartDelay) }.store(in: &cancellables)
        $overlayFadeDuration.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayFadeDuration) }.store(in: &cancellables)

        // Guardrail: 10秒到2小时 (10 - 7200秒)
        if intervalSeconds < 10 { intervalSeconds = 10 }
        if intervalSeconds > 7200 { intervalSeconds = 7200 }
        
        // Guardrail: 透明度 0.3 - 1.0
        if overlayOpacity < 0.3 { overlayOpacity = 0.3 }
        if overlayOpacity > 1.0 { overlayOpacity = 1.0 }
    }

    var lastFireDate: Date? {
        guard lastFireEpoch > 0 else { return nil }
        return Date(timeIntervalSince1970: lastFireEpoch)
    }

    func markFiredNow() {
        lastFireEpoch = Date().timeIntervalSince1970
    }
    
    // 格式化显示时间间隔
    func formattedInterval() -> String {
        let seconds = Int(intervalSeconds)
        if seconds < 60 {
            return "\(seconds) 秒"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds == 0 {
                return "\(minutes) 分钟"
            } else {
                return "\(minutes) 分 \(remainingSeconds) 秒"
            }
        } else {
            let hours = seconds / 3600
            let remainingMinutes = (seconds % 3600) / 60
            if remainingMinutes == 0 {
                return "\(hours) 小时"
            } else {
                return "\(hours) 小时 \(remainingMinutes) 分钟"
            }
        }
    }
    
    // 获取淡化持续时间（秒）
    func getFadeDuration() -> Double {
        if overlayFadeDuration < 0 {
            // 自动模式：在下一个通知到来前完成淡出
            let remainingTime = intervalSeconds - overlayFadeStartDelay
            return max(remainingTime, 3) // 至少3秒淡出时间
        } else {
            return overlayFadeDuration
        }
    }
    
    // 获取颜色
    func getOverlayColor() -> Color {
        switch overlayColor {
        case .black: return .black
        case .blue: return .blue
        case .purple: return .purple
        case .green: return .green
        case .orange: return .orange
        }
    }
}

// MARK: - Notification + Timer Controller

@MainActor
final class ReminderController: ObservableObject {
    private var timer: Timer?
    private let center = UNUserNotificationCenter.current()
    private var overlayWindow: NSWindow?

    func ensurePermission() async {
        do {
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            }
        } catch {
            // Ignore permission errors.
        }
    }

    func start(settings: AppSettings) {
        stop()

        // Determine next schedule time.
        let now = Date()
        let nextDate: Date
        if let last = settings.lastFireDate {
            let candidate = last.addingTimeInterval(settings.intervalSeconds)
            // 如果候选时间已过去，则下一次触发设为“现在 + 间隔”，避免立刻重复触发
            nextDate = candidate > now ? candidate : now.addingTimeInterval(settings.intervalSeconds)
        } else {
            nextDate = now.addingTimeInterval(settings.intervalSeconds)
        }

        // Schedule repeating timer.
        scheduleTimer(fireAt: nextDate, settings: settings)

        // ✅ 启动时立刻发一个通知
        Task { @MainActor in
            await self.sendNotification(settings: settings)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        closeOverlay()
    }

    func cleanup() async {
        // 清理定时器和未处理的通知
        stop()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    private func scheduleTimer(fireAt date: Date, settings: AppSettings) {
        let interval = settings.intervalSeconds
        let t = Timer(fire: date, interval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.sendNotification(settings: settings)
            }
        }
        self.timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    func sendTest(settings: AppSettings) async {
        await sendNotification(settings: settings)
    }

    private func sendNotification(settings: AppSettings) async {
        settings.markFiredNow()
        
        switch settings.notificationMode {
        case .system:
            await sendSystemNotification(settings: settings)
        case .overlay:
            showOverlayNotification(settings: settings)
        }
    }
    
    private func sendSystemNotification(settings: AppSettings) async {
        await ensurePermission()

        let content = UNMutableNotificationContent()
        let emoji = settings.notifEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = settings.notifTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        if !emoji.isEmpty {
            content.title = title.isEmpty ? emoji : "\(emoji) \(title)"
        } else {
            content.title = title.isEmpty ? "提醒" : title
        }

        content.body = settings.notifBody

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            // Ignore delivery errors.
        }
    }
    
    private func showOverlayNotification(settings: AppSettings) {
        // 先同步关闭旧窗口
        if let existingWindow = overlayWindow {
            existingWindow.close()
            overlayWindow = nil
        }
        
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenFrame = screen.visibleFrame
        
        // 创建遮罩窗口
        let windowWidth: CGFloat = 350
        let windowHeight: CGFloat = 120
        let padding: CGFloat = 20
        
        // 根据位置设置计算窗口位置
        let windowRect: NSRect
        switch settings.overlayPosition {
        case .topRight:
            windowRect = NSRect(
                x: screenFrame.maxX - windowWidth - padding,
                y: screenFrame.maxY - windowHeight - padding,
                width: windowWidth,
                height: windowHeight
            )
        case .topLeft:
            windowRect = NSRect(
                x: screenFrame.minX + padding,
                y: screenFrame.maxY - windowHeight - padding,
                width: windowWidth,
                height: windowHeight
            )
        case .topCenter:
            windowRect = NSRect(
                x: screenFrame.midX - windowWidth / 2,
                y: screenFrame.maxY - windowHeight - padding,
                width: windowWidth,
                height: windowHeight
            )
        case .center:
            windowRect = NSRect(
                x: screenFrame.midX - windowWidth / 2,
                y: screenFrame.midY - windowHeight / 2,
                width: windowWidth,
                height: windowHeight
            )
        }
        
        let window = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false
        
        let overlayView = OverlayNotificationView(
            emoji: settings.notifEmoji,
            title: settings.notifTitle,
            message: settings.notifBody,
            backgroundColor: settings.getOverlayColor(),
            backgroundOpacity: settings.overlayOpacity,
            fadeStartDelay: settings.overlayFadeStartDelay,
            fadeDuration: settings.getFadeDuration(),
            onDismiss: { [weak self, weak window] in
                Task { @MainActor in
                    guard let self, let w = window else { return }
                    if let current = self.overlayWindow, current === w {
                        w.orderOut(nil)
                        w.close()
                        self.overlayWindow = nil
                    }
                }
            }
        )
        
        window.contentView = NSHostingView(rootView: overlayView)
        window.makeKeyAndOrderFront(nil)
        
        self.overlayWindow = window
    }
    
    private func closeOverlay() {
        guard let window = overlayWindow else { return }
        window.orderOut(nil)
        window.close()
        overlayWindow = nil
    }
}

// MARK: - Views

struct OverlayNotificationView: View {
    let emoji: String
    let title: String
    let message: String
    let backgroundColor: Color
    let backgroundOpacity: Double
    let fadeStartDelay: Double // 开始淡化的延迟
    let fadeDuration: Double // 淡化持续时间
    let onDismiss: () -> Void
    
    @State private var opacity: Double = 1.0
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text(emoji.isEmpty ? "⏰" : emoji)
                    .font(.system(size: 40))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.isEmpty ? "提醒" : title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(message)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(20)
        }
        .frame(width: 350, height: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor.opacity(backgroundOpacity))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .opacity(opacity)
        .onAppear {
            startFadeTimer()
        }
        .onTapGesture {
            onDismiss()
        }
    }
    
    private func startFadeTimer() {
        // 在指定延迟后开始淡化
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeStartDelay) {
            withAnimation(.easeInOut(duration: fadeDuration)) {
                opacity = 0.1
            }
            
            // 淡化完成后自动关闭
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration) {
                onDismiss()
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("loopRemider")
                .font(.title2)
                .bold()

            Text(settings.isRunning ? "状态：运行中" : "状态：已暂停")
                .foregroundStyle(settings.isRunning ? .green : .secondary)

            HStack {
                Text("频率")
                Spacer()
                Text("每 \(settings.formattedInterval())")
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("提示：这是一个菜单栏应用。打开菜单栏图标进行 启动/暂停、配置、退出。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 360)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController

    @State private var sendingTest = false
    @State private var inputValue: String = ""
    @State private var selectedUnit: TimeUnit = .minutes
    @State private var selectedTab: SettingsTab = .basic
    
    enum SettingsTab: String, CaseIterable {
        case basic = "基本设置"
        case style = "通知样式"
    }
    
    enum TimeUnit: String, CaseIterable {
        case seconds = "秒"
        case minutes = "分钟"
        
        var multiplier: Double {
            switch self {
            case .seconds: return 1
            case .minutes: return 60
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Selector
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Content based on selected tab
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        if selectedTab == .basic {
                            basicSettingsContent
                        } else {
                            styleSettingsContent
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 80) // 留出浮动按钮空间
                }
                
                // 浮动测试按钮
                VStack {
                    Spacer()
                    Button {
                        sendingTest = true
                        Task {
                            await controller.sendTest(settings: settings)
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            sendingTest = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if sendingTest {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.caption)
                            }
                            Text(sendingTest ? "发送中..." : "发送测试通知")
                                .font(.callout)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(sendingTest)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .background(
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 5, y: -2)
                            .ignoresSafeArea(edges: .bottom)
                    )
                }
            }
        }
        .frame(width: 520, height: 650)
        .frame(minWidth: 520, maxWidth: 520, minHeight: 650, maxHeight: 650)
        .onAppear {
            initializeInputValue()
        }
    }
    
    // MARK: - Basic Settings Tab
    
    private var basicSettingsContent: some View {
        VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.blue.gradient)
                    Text("提醒设置")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("自定义您的循环提醒")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                // Start/Stop Toggle Section
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: settings.isRunning ? "play.circle.fill" : "pause.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(settings.isRunning ? .green : .orange)
                                Text(settings.isRunning ? "运行中" : "已暂停")
                                    .font(.headline)
                                    .foregroundStyle(settings.isRunning ? .green : .orange)
                            }
                            Text(settings.isRunning ? "定时提醒已启动" : "点击启动按钮开始提醒")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { settings.isRunning },
                            set: { newValue in
                                settings.isRunning = newValue
                                if newValue {
                                    controller.start(settings: settings)
                                } else {
                                    controller.stop()
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.large)
                        .labelsHidden()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(settings.isRunning ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(settings.isRunning ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 20)

                // Notification Mode Section
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text("通知方式")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(.purple)
                    }

                    Picker("", selection: $settings.notificationMode) {
                        ForEach(AppSettings.NotificationMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(settings.isRunning)
                    
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.purple.opacity(0.6))
                        Text(settings.notificationMode == .system ? "使用macOS系统通知中心" : "在屏幕右上角显示遮罩通知")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.leading, 24)
                    
                    if settings.isRunning {
                        HStack {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("请先暂停才能修改通知方式")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Spacer()
                        }
                        .padding(.leading, 24)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.controlBackgroundColor))
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                )
                .opacity(settings.isRunning ? 0.6 : 1.0)

                // Frequency Section
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text("通知频率")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.blue)
                    }

                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "timer")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            
                            TextField("输入间隔", text: $inputValue)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .disabled(settings.isRunning)
                                .onChange(of: inputValue) { _, newValue in
                                    updateIntervalFromInput()
                                }
                            
                            Picker("", selection: $selectedUnit) {
                                ForEach(TimeUnit.allCases, id: \.self) { unit in
                                    Text(unit.rawValue).tag(unit)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                            .disabled(settings.isRunning)
                            .onChange(of: selectedUnit) { _, _ in
                                updateIntervalFromInput()
                            }
                            
                            Spacer()
                            
                            Text(settings.formattedInterval())
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                                .frame(minWidth: 80, alignment: .trailing)
                        }

                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.blue.opacity(0.6))
                            Text("范围：10秒到2小时；建议 15～60 分钟")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.leading, 24)
                        
                        if settings.isRunning {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Text("请先暂停才能修改频率")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Spacer()
                            }
                            .padding(.leading, 24)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.controlBackgroundColor))
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                )
                .opacity(settings.isRunning ? 0.6 : 1.0)

                // Notification Content Section
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text("通知内容")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "text.bubble.fill")
                            .foregroundStyle(.green)
                    }

                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "textformat")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            TextField("标题", text: $settings.notifTitle)
                                .textFieldStyle(.roundedBorder)
                                .disabled(settings.isRunning)
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                                .padding(.top, 6)
                            TextField("内容", text: $settings.notifBody, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...5)
                                .disabled(settings.isRunning)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "face.smiling")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            TextField("Emoji（显示在标题前）", text: $settings.notifEmoji)
                                .textFieldStyle(.roundedBorder)
                                .disabled(settings.isRunning)
                            Text(settings.notifEmoji.isEmpty ? "🔔" : settings.notifEmoji)
                                .font(.title2)
                                .frame(width: 40)
                        }

                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green.opacity(0.6))
                            Text("Emoji 使用 macOS 的 Apple Color Emoji 字体渲染")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.leading, 24)
                        
                        if settings.isRunning {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Text("请先暂停才能修改内容")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Spacer()
                            }
                            .padding(.leading, 24)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.controlBackgroundColor))
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                )
                .opacity(settings.isRunning ? 0.6 : 1.0)

                Spacer(minLength: 20)
        }
    }
    
    // MARK: - Style Settings Tab
    
    private var styleSettingsContent: some View {
        VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.pink.gradient)
                    Text("通知样式")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("自定义屏幕遮罩通知外观")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
                
                // Style settings only available for overlay mode
                if settings.notificationMode == .overlay {
                    // Position
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label {
                                Text("位置")
                                    .font(.headline)
                            } icon: {
                                Image(systemName: "location.fill")
                                    .foregroundStyle(.blue)
                            }
                            .frame(width: 100, alignment: .leading)
                            
                            Spacer()
                            
                            Picker("", selection: $settings.overlayPosition) {
                                ForEach(AppSettings.OverlayPosition.allCases, id: \.self) { position in
                                    Text(position.rawValue).tag(position)
                                }
                            }
                            .pickerStyle(.segmented)
                            .disabled(settings.isRunning)
                            .frame(width: 340)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.controlBackgroundColor))
                            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    )
                    .opacity(settings.isRunning ? 0.6 : 1.0)
                    
                    // Color
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label {
                                Text("颜色")
                                    .font(.headline)
                            } icon: {
                                Image(systemName: "paintpalette.fill")
                                    .foregroundStyle(.purple)
                            }
                            .frame(width: 100, alignment: .leading)
                            
                            Spacer()
                            
                            Picker("", selection: $settings.overlayColor) {
                                ForEach(AppSettings.OverlayColor.allCases, id: \.self) { color in
                                    Text(color.rawValue).tag(color)
                                }
                            }
                            .pickerStyle(.segmented)
                            .disabled(settings.isRunning)
                            .frame(width: 340)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.controlBackgroundColor))
                            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    )
                    .opacity(settings.isRunning ? 0.6 : 1.0)
                    
                    // Opacity
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label {
                                Text("透明度")
                                    .font(.headline)
                            } icon: {
                                Image(systemName: "circle.lefthalf.filled")
                                    .foregroundStyle(.orange)
                            }
                            .frame(width: 100, alignment: .leading)
                            
                            Spacer()
                            
                            Slider(value: $settings.overlayOpacity, in: 0.3...1.0, step: 0.05)
                                .disabled(settings.isRunning)
                                .frame(width: 280)
                            Text(String(format: "%.0f%%", settings.overlayOpacity * 100))
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.controlBackgroundColor))
                            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    )
                    .opacity(settings.isRunning ? 0.6 : 1.0)
                    
                    // 淡化延迟（开始时机）
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label {
                                Text("淡化延迟")
                                    .font(.headline)
                            } icon: {
                                Image(systemName: "timer")
                                    .foregroundStyle(.teal)
                            }
                            .frame(width: 100, alignment: .leading)
                            
                            Spacer()
                            
                            Slider(value: $settings.overlayFadeStartDelay, in: 0...10, step: 0.5)
                                .disabled(settings.isRunning)
                                .frame(width: 280)
                            Text(String(format: "%.1f秒", settings.overlayFadeStartDelay))
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(.teal)
                                .frame(width: 50, alignment: .trailing)
                        }
                        
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.teal.opacity(0.6))
                            Text("通知显示后，等待多久开始淡化")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.controlBackgroundColor))
                            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    )
                    .opacity(settings.isRunning ? 0.6 : 1.0)
                    
                    // 淡化持续时间
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label {
                                Text("淡化时长")
                                    .font(.headline)
                            } icon: {
                                Image(systemName: "clock.badge.checkmark.fill")
                                    .foregroundStyle(.green)
                            }
                            .frame(width: 100, alignment: .leading)
                            
                            Spacer()
                        }
                        
                        if settings.overlayFadeDuration < 0 {
                            HStack {
                                Text("自动（到下次通知前淡化完毕）")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("手动设置") {
                                    Task { @MainActor in
                                        settings.overlayFadeDuration = 10
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(settings.isRunning)
                            }
                        } else {
                            HStack {
                                Slider(value: $settings.overlayFadeDuration, in: 1...120, step: 1)
                                    .disabled(settings.isRunning)
                                    .frame(width: 280)
                                Text("\(Int(settings.overlayFadeDuration))秒")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                                    .frame(width: 50, alignment: .trailing)
                                Button("自动") {
                                    Task { @MainActor in
                                        settings.overlayFadeDuration = -1
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(settings.isRunning)
                            }
                        }
                        
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green.opacity(0.6))
                            Text("从开始淡化到完全消失的时间")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.controlBackgroundColor))
                            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    )
                    .opacity(settings.isRunning ? 0.6 : 1.0)
                    
                    if settings.isRunning {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.orange)
                            Text("请先暂停才能修改样式")
                                .font(.callout)
                                .foregroundStyle(.orange)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.1))
                        )
                    }
                } else {
                    // Message when system notification mode is selected
                    VStack(spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("仅在屏幕遮罩模式下可用")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("请在基本设置中将通知方式改为屏幕遮罩")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                }

                Spacer(minLength: 20)
        }
    }
    
    private func initializeInputValue() {
        let seconds = settings.intervalSeconds
        if seconds >= 60 && Int(seconds) % 60 == 0 {
            // 如果是整分钟，默认显示分钟
            selectedUnit = .minutes
            inputValue = String(Int(seconds / 60))
        } else {
            // 否则显示秒
            selectedUnit = .seconds
            inputValue = String(Int(seconds))
        }
    }
    
    private func updateIntervalFromInput() {
        guard let value = Double(inputValue), value > 0 else {
            return
        }
        
        var seconds = value * selectedUnit.multiplier
        
        // 自动修正：小于10秒则设为10秒
        if seconds < 10 {
            seconds = 10
            // 更新输入框显示
            if selectedUnit == .seconds {
                inputValue = "10"
            } else {
                inputValue = String(format: "%.1f", 10 / 60.0)
            }
        }
        
        // 限制范围：10秒到7200秒(2小时)
        if seconds >= 10 && seconds <= 7200 {
            settings.intervalSeconds = seconds
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
        .environmentObject(ReminderController())
}
