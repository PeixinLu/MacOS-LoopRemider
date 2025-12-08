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

@MainActor
final class ReminderController: ObservableObject {
    private var timer: Timer?
    private let center = UNUserNotificationCenter.current()
    private var overlayWindow: NSPanel?  // 使用 NSPanel 替代 NSWindow 以支持全屏模式

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

        let now = Date()
        let nextDate: Date
        if let last = settings.lastFireDate {
            let candidate = last.addingTimeInterval(settings.intervalSeconds)
            nextDate = candidate > now ? candidate : now.addingTimeInterval(settings.intervalSeconds)
        } else {
            nextDate = now.addingTimeInterval(settings.intervalSeconds)
        }

        scheduleTimer(fireAt: nextDate, settings: settings)

        Task {
            await self.sendNotification(settings: settings)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        closeOverlay()
    }

    func cleanup() {
        stop()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    private func scheduleTimer(fireAt date: Date, settings: AppSettings) {
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
        // 先关闭已存在的遮罩窗口
        if let existingWindow = overlayWindow {
            existingWindow.close()
            overlayWindow = nil
        }
        
        // 获取主屏幕或第一个可用屏幕
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenFrame = screen.visibleFrame
        
        let windowWidth: CGFloat = settings.overlayWidth
        let windowHeight: CGFloat = settings.overlayHeight
        let padding: CGFloat = settings.overlayEdgePadding
        
        // 为动画添加缓冲区，避免裁切感
        let buffer: CGFloat = 100
        
        // 窗口尺寸包含缓冲区
        let expandedWidth: CGFloat
        let expandedHeight: CGFloat
        
        // 窗口位置：贴靠屏幕边缘，但内容保留padding
        let windowRect: NSRect
        switch settings.overlayPosition {
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
            emoji: settings.notifEmoji,
            title: settings.notifTitle,
            message: settings.notifBody,
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
            padding: padding,
            onDismiss: { [weak self, weak window] in
                Task {
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
        // 使用 orderFrontRegardless 确保窗口显示在最前方，即使在全屏模式下
        window.orderFrontRegardless()
        
        // 调试信息：确认窗口配置
        print("🔔 遮罩通知窗口已创建")
        print("   - 窗口级别: \(window.level.rawValue)")
        print("   - Collection Behavior: \(window.collectionBehavior)")
        print("   - 是否浮动面板: \(window.isFloatingPanel)")
        print("   - 窗口位置: \(windowRect)")
        print("   - 窗口可见: \(window.isVisible)")
        
        self.overlayWindow = window
    }
    
    private func closeOverlay() {
        guard let window = overlayWindow else { return }
        window.orderOut(nil)
        window.close()
        overlayWindow = nil
    }
}
