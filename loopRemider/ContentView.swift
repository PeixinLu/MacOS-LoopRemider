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
    }

    private let defaults = UserDefaults.standard
    private var cancellables: Set<AnyCancellable> = []

    // Observable values
    @Published var isRunning: Bool
    @Published var intervalSeconds: Double
    @Published var notificationMode: NotificationMode

    @Published var notifTitle: String
    @Published var notifBody: String
    @Published var notifEmoji: String

    @Published var lastFireEpoch: Double
    
    enum NotificationMode: String, CaseIterable {
        case system = "系统通知"
        case overlay = "屏幕遮罩"
    }

    init() {
        // Load
        self.isRunning = defaults.object(forKey: Keys.isRunning) as? Bool ?? false
        self.intervalSeconds = defaults.object(forKey: Keys.intervalSeconds) as? Double ?? 1800 // 默认30分钟
        self.notifTitle = defaults.string(forKey: Keys.notifTitle) ?? "提醒"
        self.notifBody = defaults.string(forKey: Keys.notifBody) ?? "起来活动一下～"
        self.notifEmoji = defaults.string(forKey: Keys.notifEmoji) ?? "⏰"
        self.lastFireEpoch = defaults.object(forKey: Keys.lastFire) as? Double ?? 0
        
        let modeRawValue = defaults.string(forKey: Keys.notificationMode) ?? NotificationMode.system.rawValue
        self.notificationMode = NotificationMode(rawValue: modeRawValue) ?? .system

        // Persist changes
        $isRunning.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.isRunning) }.store(in: &cancellables)
        $intervalSeconds.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.intervalSeconds) }.store(in: &cancellables)
        $notifTitle.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.notifTitle) }.store(in: &cancellables)
        $notifBody.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.notifBody) }.store(in: &cancellables)
        $notifEmoji.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.notifEmoji) }.store(in: &cancellables)
        $lastFireEpoch.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.lastFire) }.store(in: &cancellables)
        $notificationMode.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.notificationMode) }.store(in: &cancellables)

        // Guardrail: 10秒到2小时 (10 - 7200秒)
        if intervalSeconds < 10 { intervalSeconds = 10 }
        if intervalSeconds > 7200 { intervalSeconds = 7200 }
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
            nextDate = max(candidate, now)
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
        
        // 创建遮罩窗口，位于右上角
        let windowWidth: CGFloat = 350
        let windowHeight: CGFloat = 120
        let padding: CGFloat = 20
        
        let windowRect = NSRect(
            x: screenFrame.maxX - windowWidth - padding,
            y: screenFrame.maxY - windowHeight - padding,
            width: windowWidth,
            height: windowHeight
        )
        
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
            onDismiss: { [weak self] in
                Task { @MainActor in
                    self?.closeOverlay()
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
    let onDismiss: () -> Void
    
    @State private var opacity: Double = 1.0
    @State private var fadeTimer: Timer?
    
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
                .fill(Color.black.opacity(0.85))
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
        // 3秒后开始淡出，怰10秒内逐渐变淡
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeInOut(duration: 10)) {
                opacity = 0.1
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
        ScrollView {
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

                // Test Button Section
                VStack(spacing: 12) {
                    Button {
                        sendingTest = true
                        Task {
                            await controller.sendTest(settings: settings)
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            sendingTest = false
                        }
                    } label: {
                        HStack {
                            if sendingTest {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 4)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text(sendingTest ? "发送中..." : "发送测试通知")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(sendingTest)
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
        }
        .frame(width: 520, height: 650)
        .frame(minWidth: 520, maxWidth: 520, minHeight: 650, maxHeight: 650)
        .onAppear {
            initializeInputValue()
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
