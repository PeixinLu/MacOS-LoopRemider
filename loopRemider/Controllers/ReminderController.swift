//
//  ReminderController.swift
//  loopRemider
//
//  Created by 数源 on 2025/12/8.
//

import SwiftUI
import UserNotifications
import AppKit
import Combine
import os

@MainActor
final class ReminderController: ObservableObject {
    @Published var isResting: Bool = false

    private var timer: Timer?
    private var restTimer: Timer?
    private let center = UNUserNotificationCenter.current()
    private var overlayWindow: NSPanel?  // 使用 NSPanel 替代 NSWindow 以支持全屏模式
    private weak var settingsRef: AppSettings?
    private var lockObserver: NSObjectProtocol?
    private var unlockObserver: NSObjectProtocol?
    private var lastLockDate: Date?
    private let logger = EventLogger.shared
    private struct NotificationContent {
        let emoji: String
        let title: String
        let body: String
    }
    
    deinit {
        Task { @MainActor in
            self.removeLockObservers()
        }
    }
    private struct OverlayStyle {
        let backgroundColor: Color
        let backgroundOpacity: Double
        let stayDuration: Double
        let enableFadeOut: Bool
        let fadeOutDelay: Double
        let fadeOutDuration: Double
        let titleFontSize: Double
        let bodyFontSize: Double
        let iconSize: Double
        let cornerRadius: Double
        let contentSpacing: Double
        let useBlur: Bool
        let blurIntensity: Double
        let overlayWidth: Double
        let overlayHeight: Double
        let animationStyle: AppSettings.AnimationStyle
        let position: AppSettings.OverlayPosition
        let padding: Double
        let textColor: Color?
    }

    func ensurePermission() async {
        do {
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            }
        } catch {
            logger.log("请求通知权限失败: \(error.localizedDescription)")
        }
    }

    func start(settings: AppSettings) {
        // 验证内容是否有效
        guard settings.isContentValid() else {
            print("⚠️ 无法启动：标题、描述和Emoji至少需要有一项不为空")
            return
        }
        
        settingsRef = settings
        ensureLockMonitoring()
        logger.log("启动计时器: 间隔 \(Int(settings.intervalSeconds))s, 模式 \(settings.notificationMode.rawValue)")
        
        stop()

        let now = Date()
        // 计算第一次触发的时间
        let nextDate = now.addingTimeInterval(settings.intervalSeconds)

        // 安排计时器，但不立即触发
        scheduleTimer(fireAt: nextDate, settings: settings)

        // 启动时弹出一次通知（固定样式），不影响计时进度
        Task {
            await self.sendStartNotification(settings: settings)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        restTimer?.invalidate()
        restTimer = nil
        isResting = false
        closeOverlay()
        logger.log("计时器已停止")
    }

    func cleanup() {
        stop()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        // 退出应用时强制标记为未运行，避免下次启动仍显示倒计时
        settingsRef?.isRunning = false
        settingsRef?.lastFireEpoch = 0
        logger.log("应用清理完成，计时状态重置")
    }

    private func scheduleTimer(fireAt date: Date, settings: AppSettings) {
        // 更新触发时间，以便UI能正确显示倒计时
        settings.lastFireEpoch = date.timeIntervalSince1970 - settings.intervalSeconds

        let interval = settings.intervalSeconds
        let t = Timer(fire: date, interval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.sendNotification(settings: settings)
            }
        }
        self.timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    private func scheduleRestTimer(settings: AppSettings) {
        isResting = true
        let restInterval = settings.restSeconds

        // 更新UI状态
        settings.lastFireEpoch = Date().timeIntervalSince1970

        restTimer = Timer.scheduledTimer(withTimeInterval: restInterval, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.isResting = false
            // 休息结束后，安排下一次常规通知
            self.scheduleTimer(fireAt: Date().addingTimeInterval(settings.intervalSeconds), settings: settings)
        }
    }

    func sendTest(settings: AppSettings) async {
        // 验证内容是否有效
        guard settings.isContentValid() else {
            print("⚠️ 无法发送测试通知：标题、描述和Emoji至少需要有一项不为空")
            return
        }
        
        // 测试通知不影响常规计时
        await sendNotification(settings: settings, isTest: true, triggerRestOnDismiss: false)
    }

    private func sendNotification(settings: AppSettings, isTest: Bool = false, content: NotificationContent? = nil, overlayStyle: OverlayStyle? = nil, triggerRestOnDismiss: Bool = true) async {
        if !isTest {
            settings.markFiredNow()
        }

        let payload = content ?? buildContent(settings: settings)
        let style = overlayStyle ?? buildOverlayStyle(settings: settings)
        logger.log("发送通知: \(payload.title.isEmpty ? "(无标题)" : payload.title) | 模式 \(settings.notificationMode.rawValue)\(isTest ? " [测试]" : "")")
        
        switch settings.notificationMode {
        case .system:
            await sendSystemNotification(content: payload)
        case .overlay:
            showOverlayNotification(settings: settings, content: payload, style: style, triggerRestOnDismiss: triggerRestOnDismiss)
        }
    }
    
    private func sendStartLikeNotification(settings: AppSettings, title: String, body: String) async {
        let content = NotificationContent(
            emoji: "🔔",
            title: title,
            body: body
        )
        let style = buildStartOverlayStyle(settings: settings)
        logger.log(title)
        await sendNotification(
            settings: settings,
            isTest: true,
            content: content,
            overlayStyle: style,
            triggerRestOnDismiss: false
        )
    }
    
    private func sendStartNotification(settings: AppSettings) async {
        await sendStartLikeNotification(
            settings: settings,
            title: "计时器已启动",
            body: "循环提醒已开始计时"
        )
    }
    
    private func sendResetNotification(settings: AppSettings) async {
        await sendStartLikeNotification(
            settings: settings,
            title: "计时器已重置",
            body: "已重新开始计时"
        )
    }
    
    private func buildContent(settings: AppSettings, customTitle: String? = nil, customBody: String? = nil, customEmoji: String? = nil) -> NotificationContent {
        let emoji = (customEmoji ?? settings.notifEmoji).trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (customTitle ?? settings.notifTitle).trimmingCharacters(in: .whitespacesAndNewlines)
        let body = customBody ?? settings.notifBody
        return NotificationContent(emoji: emoji, title: title, body: body)
    }
    
    private func buildOverlayStyle(settings: AppSettings) -> OverlayStyle {
        return OverlayStyle(
            backgroundColor: settings.getOverlayColor(),
            backgroundOpacity: settings.overlayOpacity,
            stayDuration: settings.overlayStayDuration,
            enableFadeOut: settings.overlayEnableFadeOut,
            fadeOutDelay: settings.overlayFadeOutDelay,
            fadeOutDuration: settings.overlayFadeOutDuration,
            titleFontSize: settings.overlayTitleFontSize,
            bodyFontSize: settings.overlayBodyFontSize,
            iconSize: settings.overlayIconSize,
            cornerRadius: settings.overlayCornerRadius,
            contentSpacing: settings.overlayContentSpacing,
            useBlur: settings.overlayUseBlur,
            blurIntensity: settings.overlayBlurIntensity,
            overlayWidth: settings.overlayWidth,
            overlayHeight: settings.overlayHeight,
            animationStyle: settings.animationStyle,
            position: settings.overlayPosition,
            padding: settings.overlayEdgePadding,
            textColor: nil
        )
    }
    
    private func buildStartOverlayStyle(settings: AppSettings) -> OverlayStyle {
        let isDark = isDarkModeEnabled()
        let background = isDark ? Color(red: 0.12, green: 0.14, blue: 0.16) : Color.white
        let opacity = isDark ? 0.85 : 0.95
        let textColor: Color = isDark ? .white : Color(red: 0.12, green: 0.14, blue: 0.16)
        
        return OverlayStyle(
            backgroundColor: background,
            backgroundOpacity: opacity,
            stayDuration: 2.8,
            enableFadeOut: false, // 启动提示不单独淡化内容，只做整体淡入淡出
            fadeOutDelay: 0,
            fadeOutDuration: 0.35,
            titleFontSize: 16,
            bodyFontSize: 13,
            iconSize: 22,
            cornerRadius: 18,
            contentSpacing: 12,
            useBlur: true,
            blurIntensity: 0.5,
            overlayWidth: 280,
            overlayHeight: 96,
            animationStyle: .fade,
            position: settings.overlayPosition,
            padding: settings.overlayEdgePadding,
            textColor: textColor
        )
    }

    private func isDarkModeEnabled() -> Bool {
        guard let appearance = NSApp?.effectiveAppearance else { return true }
        let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
        return bestMatch == .darkAqua
    }
    
    // MARK: - Lock/Unlock Handling
    
    private func ensureLockMonitoring() {
        let center = DistributedNotificationCenter.default()
        
        if lockObserver == nil {
            lockObserver = center.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: nil) { [weak self] _ in
                Task { @MainActor in
                    self?.lastLockDate = Date()
                }
            }
        }
        
        if unlockObserver == nil {
            unlockObserver = center.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: nil) { [weak self] _ in
                Task { @MainActor in
                    self?.handleUnlock()
                }
            }
        }
    }
    
    private func removeLockObservers() {
        let center = DistributedNotificationCenter.default()
        if let observer = lockObserver {
            center.removeObserver(observer)
            lockObserver = nil
        }
        if let observer = unlockObserver {
            center.removeObserver(observer)
            unlockObserver = nil
        }
    }
    
    private func handleUnlock() {
        guard let settings = settingsRef, settings.resetOnWakeEnabled else { return }
        guard let lockDate = lastLockDate else { return }
        lastLockDate = nil
        
        let elapsed = Date().timeIntervalSince(lockDate)
        guard elapsed >= 300 else { return } // 锁屏超过5分钟重置计时器
        guard settings.isRunning else { return }
        
        restartAfterUnlock(settings: settings)
    }
    
    private func restartAfterUnlock(settings: AppSettings) {
        stop()
        let nextDate = Date().addingTimeInterval(settings.intervalSeconds)
        scheduleTimer(fireAt: nextDate, settings: settings)
        Task {
            await sendResetNotification(settings: settings)
        }
        logger.log("解锁后重置计时器")
    }

    private func sendSystemNotification(content payload: NotificationContent) async {
        await ensurePermission()

        let notificationContent = UNMutableNotificationContent()
        let emoji = payload.emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)

        if !emoji.isEmpty {
            notificationContent.title = title.isEmpty ? emoji : "\(emoji) \(title)"
        } else {
            notificationContent.title = title.isEmpty ? "提醒" : title
        }

        notificationContent.body = payload.body

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: notificationContent,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            logger.log("发送系统通知失败: \(error.localizedDescription)")
        }
    }
    
    private func showOverlayNotification(settings: AppSettings, content: NotificationContent, style: OverlayStyle, triggerRestOnDismiss: Bool) {
        // 先关闭已存在的遮罩窗口
        if let existingWindow = overlayWindow {
            existingWindow.close()
            overlayWindow = nil
        }
        
        // 获取主屏幕或第一个可用屏幕
        let screen: NSScreen?
        switch settings.screenSelection {
        case .active:
            // 活跃屏幕：包含当前获得焦点的窗口所在的屏幕
            screen = NSScreen.main ?? NSScreen.screens.first
        case .mouse:
            // 鼠标所在屏幕：根据鼠标光标位置确定屏幕
            let mouseLocation = NSEvent.mouseLocation
            screen = NSScreen.screens.first { screen in
                screen.frame.contains(mouseLocation)
            } ?? NSScreen.main ?? NSScreen.screens.first
        }
        
        guard let screen else {
            logger.log("未找到可用屏幕，遮罩通知未显示")
            return
        }
        let screenFrame = screen.visibleFrame
        
        // 调试信息：显示屏幕选择
        print("🖥️  屏幕选择信息：")
        print("   - 选择模式: \(settings.screenSelection.rawValue)")
        print("   - 总屏幕数: \(NSScreen.screens.count)")
        if settings.screenSelection == .mouse {
            let mouseLocation = NSEvent.mouseLocation
            print("   - 鼠标位置: (\(mouseLocation.x), \(mouseLocation.y))")
        }
        if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            print("   - 使用屏幕编号: \(screenNumber)")
        }
        print("   - 屏幕Frame: \(screen.frame)")
        print("   - 可见Frame: \(screenFrame)")
        
        let windowWidth: CGFloat = style.overlayWidth
        let windowHeight: CGFloat = style.overlayHeight
        let padding: CGFloat = style.padding
        
        // 为动画添加缓冲区，避免裁切感
        let buffer: CGFloat = 100
        
        // 窗口尺寸包含缓冲区
        let expandedWidth: CGFloat
        let expandedHeight: CGFloat
        
        // 窗口位置：贴靠屏幕边缘，但内容保留padding
        let windowRect: NSRect
        switch style.position {
        case .topLeft:
            expandedWidth = windowWidth + buffer
            expandedHeight = windowHeight + buffer
            windowRect = NSRect(
                x: screenFrame.minX,
                y: screenFrame.maxY - expandedHeight,
                width: expandedWidth,
                height: expandedHeight
            )
        case .topRight:
            expandedWidth = windowWidth + buffer
            expandedHeight = windowHeight + buffer
            windowRect = NSRect(
                x: screenFrame.maxX - expandedWidth,
                y: screenFrame.maxY - expandedHeight,
                width: expandedWidth,
                height: expandedHeight
            )
        case .bottomLeft:
            expandedWidth = windowWidth + buffer
            expandedHeight = windowHeight + buffer + 80
            windowRect = NSRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: expandedWidth,
                height: expandedHeight
            )
        case .bottomRight:
            expandedWidth = windowWidth + buffer
            expandedHeight = windowHeight + buffer + 80
            windowRect = NSRect(
                x: screenFrame.maxX - expandedWidth,
                y: screenFrame.minY,
                width: expandedWidth,
                height: expandedHeight
            )
        case .topCenter:
            expandedWidth = windowWidth
            expandedHeight = windowHeight + buffer
            windowRect = NSRect(
                x: screenFrame.midX - expandedWidth / 2,
                y: screenFrame.maxY - expandedHeight,
                width: expandedWidth,
                height: expandedHeight
            )
        case .center:
            expandedWidth = windowWidth + buffer
            expandedHeight = windowHeight + buffer
            windowRect = NSRect(
                x: screenFrame.midX - expandedWidth / 2,
                y: screenFrame.midY - expandedHeight / 2,
                width: expandedWidth,
                height: expandedHeight
            )
        case .bottomCenter:
            expandedWidth = windowWidth
            expandedHeight = windowHeight + buffer + 80
            windowRect = NSRect(
                x: screenFrame.midX - expandedWidth / 2,
                y: screenFrame.minY,
                width: expandedWidth,
                height: expandedHeight
            )
        }
        
        let window = NSPanel(
            contentRect: windowRect,
            styleMask: [.borderless, .nonactivatingPanel],  // 使用 nonactivatingPanel 以不激活窗口
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        // 使用 popUpMenu 级别确保在全屏应用上方显示
        window.level = .popUpMenu
        // 配置窗口行为：可加入所有空间、在全屏应用上方显示
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false
        // 确保窗口不会被激活打断用户操作
        window.hidesOnDeactivate = false
        // 关键：设置为浮动面板，允许在全屏应用上方显示
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = true
        
        let overlayView = OverlayNotificationView(
            emoji: content.emoji,
            title: content.title,
            message: content.body,
            backgroundColor: style.backgroundColor,
            backgroundOpacity: style.backgroundOpacity,
            stayDuration: style.stayDuration,
            enableFadeOut: style.enableFadeOut,
            fadeOutDelay: style.fadeOutDelay,
            fadeOutDuration: style.fadeOutDuration,
            titleFontSize: style.titleFontSize,
            bodyFontSize: style.bodyFontSize,
            iconSize: style.iconSize,
            cornerRadius: style.cornerRadius,
            contentSpacing: style.contentSpacing,
            useBlur: style.useBlur,
            blurIntensity: style.blurIntensity,
            overlayWidth: style.overlayWidth,
            overlayHeight: style.overlayHeight,
            animationStyle: style.animationStyle,
            position: style.position,
            padding: padding,
            textColor: style.textColor,
            onDismiss: { [weak self, weak window] isUserDismiss in
                Task {
                    guard let self, let w = window else { return }
                    if let current = self.overlayWindow, current === w {
                        // ... existing code ...
                        // 优集窗口关闭，防止闪烁
                        w.alphaValue = 0 // 先设置不透明度为0，立即隐藏
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak w] in
                            w?.orderOut(nil)
                            w?.close()
                        }
                        self.overlayWindow = nil
                        
                        // 只有用户手动关闭通知时才触发休息机制
                        if triggerRestOnDismiss && isUserDismiss && settings.isRestEnabled {
                            self.timer?.invalidate()
                            self.timer = nil
                            self.scheduleRestTimer(settings: settings)
                        }
                    }
                }
            }
        )
        
        window.contentView = NSHostingView(rootView: overlayView)
        // 使用 orderFrontRegardless 确保窗口显示在最前方，即使在全屏模式下
        window.orderFrontRegardless()
        
        // 调试信息：确认窗口配置
        print("🔔 遮罩通知窗口已创建")
        print("   - 窗口级别: \(window.level.rawValue)")
        print("   - 窗口位置: \(windowRect)")
        print("   - 窗口可见: \(window.isVisible)")
        print("   - 是否浮动面板: \(window.isFloatingPanel)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        self.overlayWindow = window
    }
    
    private func closeOverlay() {
        guard let window = overlayWindow else { return }
        window.orderOut(nil)
        window.close()
        overlayWindow = nil
    }
}
