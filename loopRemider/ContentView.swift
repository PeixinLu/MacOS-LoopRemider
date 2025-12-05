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
        static let intervalMinutes = "intervalMinutes"
        static let notifTitle = "notifTitle"
        static let notifBody = "notifBody"
        static let notifEmoji = "notifEmoji"
        static let lastFire = "lastFire"
    }

    private let defaults = UserDefaults.standard
    private var cancellables: Set<AnyCancellable> = []

    // Observable values
    @Published var isRunning: Bool
    @Published var intervalMinutes: Double

    @Published var notifTitle: String
    @Published var notifBody: String
    @Published var notifEmoji: String

    @Published var lastFireEpoch: Double

    init() {
        // Load
        self.isRunning = defaults.object(forKey: Keys.isRunning) as? Bool ?? false
        self.intervalMinutes = defaults.object(forKey: Keys.intervalMinutes) as? Double ?? 30
        self.notifTitle = defaults.string(forKey: Keys.notifTitle) ?? "提醒"
        self.notifBody = defaults.string(forKey: Keys.notifBody) ?? "起来活动一下～"
        self.notifEmoji = defaults.string(forKey: Keys.notifEmoji) ?? "⏰"
        self.lastFireEpoch = defaults.object(forKey: Keys.lastFire) as? Double ?? 0

        // Persist changes
        $isRunning.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.isRunning) }.store(in: &cancellables)
        $intervalMinutes.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.intervalMinutes) }.store(in: &cancellables)
        $notifTitle.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.notifTitle) }.store(in: &cancellables)
        $notifBody.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.notifBody) }.store(in: &cancellables)
        $notifEmoji.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.notifEmoji) }.store(in: &cancellables)
        $lastFireEpoch.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.lastFire) }.store(in: &cancellables)

        // Guardrail
        if intervalMinutes < 1 { intervalMinutes = 1 }
    }

    var intervalSeconds: TimeInterval {
        max(60, intervalMinutes * 60) // minimum 1 minute
    }

    var lastFireDate: Date? {
        guard lastFireEpoch > 0 else { return nil }
        return Date(timeIntervalSince1970: lastFireEpoch)
    }

    func markFiredNow() {
        lastFireEpoch = Date().timeIntervalSince1970
    }
}

// MARK: - Notification + Timer Controller

@MainActor
final class ReminderController: ObservableObject {
    private var timer: Timer?
    private let center = UNUserNotificationCenter.current()

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
            settings.markFiredNow()
        } catch {
            // Ignore delivery errors.
        }
    }
}

// MARK: - Views

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
                Text("每 \(Int(settings.intervalMinutes)) 分钟")
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
                        HStack {
                            Image(systemName: "timer")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Slider(value: $settings.intervalMinutes, in: 1...240, step: 1)
                                .tint(.blue)
                                .disabled(settings.isRunning)
                            Text("\(Int(settings.intervalMinutes))")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                                .frame(width: 40, alignment: .trailing)
                            Text("分钟")
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .leading)
                        }

                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.blue.opacity(0.6))
                            Text("最小 1 分钟；建议 15～60 分钟")
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
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
        .environmentObject(ReminderController())
}
