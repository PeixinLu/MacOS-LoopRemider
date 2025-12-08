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
        if let existingWindow = overlayWindow {
            existingWindow.close()
            overlayWindow = nil
        }
        
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
