//
//  PreviewSectionView.swift
//  loopRemider
//
//  Created by 数源 on 2025/12/8.
//

import SwiftUI

struct PreviewSectionView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController
    
    @Binding var sendingTest: Bool
    @Binding var countdownText: String
    @Binding var progressValue: Double
    @Binding var isResting: Bool
    var showTimerList: Bool = false // 是否显示计时器列表
    var onNavigateToTimers: (() -> Void)? = nil // 跳转到计时器页面

    var body: some View {
        VStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
            if showTimerList {
                // 显示计时器列表
                timerListView
            } else {
                // 显示单个计时器预览
                singleTimerPreviewView
            }
            
            Spacer()
        }
    }
    
    // MARK: - Single Timer Preview View
    
    private var singleTimerPreviewView: some View {
        VStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
            // 预览区域
            previewArea
            
            Divider()
                .padding(.vertical, DesignTokens.Spacing.sm)
            
            // 测试按钮
            testButton
        }
    }
    
    // MARK: - Timer List View
    
    private var timerListView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "timer.circle.fill")
                    .foregroundStyle(.blue)
                Text("实时预览")
                    .font(.headline)
                Spacer()
                Button {
                    onNavigateToTimers?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape.fill")
                            .font(.caption)
                        Text("计时器配置")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.blue)
            }
            
            // 预览区域
            previewAreaForFocusedTimer
            
            Divider()
                .padding(.vertical, DesignTokens.Spacing.sm)
            
            // 计时器列表
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(settings.timers) { timer in
                        TimerListItemView(
                            timer: timer,
                            isFocused: settings.focusedTimerID == timer.id,
                            isRunning: settings.isRunning,
                            onToggle: {
                                toggleTimer(timer)
                            },
                            onFocus: {
                                settings.focusedTimerID = timer.id
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: 150)
            
            // 测试按钮
            testButton
        }
        .frame(width: 380)
    }
    
    // MARK: - Preview Area
    
    private var previewArea: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "eye.fill")
                    .foregroundStyle(.blue)
                Text("实时预览")
                    .font(.headline)
            }
            
            previewNotificationContainer
            
            Text("实际显示效果可能因系统设置而略有不同")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Preview Area For Focused Timer
    
    private var previewAreaForFocusedTimer: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            previewNotificationContainer
            
            Text("预览当前焦点的计时器")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Preview Notification Container
    
    private var previewNotificationContainer: some View {
        ZStack {
            // 外层：黑色边框，模拟显示器外壳
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            
            // 内层：透明的屏幕区域（使用视觉效果实现真正的透明）
            VisualEffectTransparentView()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(8) // 边框宽度
                .overlay(
                    GeometryReader { geometry in
                        let screenWidth = geometry.size.width - 16
                        let screenHeight = geometry.size.height - 16
                        
                        if let focusedTimer = getFocusedTimer() {
                            let notifWidth = settings.overlayWidth
                            let notifHeight = settings.overlayHeight
                            
                            let widthScale = notifWidth > screenWidth ? screenWidth / notifWidth : 1.0
                            let heightScale = notifHeight > screenHeight ? screenHeight / notifHeight : 1.0
                            let scale = min(widthScale, heightScale, 1.0)
                            
                            let backgroundColor = focusedTimer.customColor?.toColor() ?? settings.getOverlayColor()
                            
                            ZStack {
                                OverlayNotificationView(
                                    emoji: focusedTimer.emoji,
                                    title: focusedTimer.title,
                                    message: focusedTimer.body,
                                    backgroundColor: backgroundColor,
                                    backgroundOpacity: settings.overlayOpacity,
                                    stayDuration: 999,
                                    enableFadeOut: false,
                                    fadeOutDelay: 0,
                                    fadeOutDuration: 1,
                                    titleFontSize: settings.overlayTitleFontSize * scale,
                                    bodyFontSize: settings.overlayBodyFontSize * scale,
                                    iconSize: settings.overlayIconSize * scale,
                                    cornerRadius: settings.overlayCornerRadius * scale,
                                    contentSpacing: settings.overlayContentSpacing * scale,
                                    useBlur: settings.overlayUseBlur,
                                    blurIntensity: settings.overlayBlurIntensity,
                                    overlayWidth: settings.overlayWidth * scale,
                                    overlayHeight: settings.overlayHeight * scale,
                                    animationStyle: .fade,
                                    position: .center,
                                    padding: 0,
                                    textColor: nil,
                                    onDismiss: { _ in }
                                )
                            }
                        }
                    }
                    .padding(8)
                )
        }
        .frame(width: 380, height: 240)
    }
    
    // MARK: - Test Button
    
    private var testButton: some View {
        Button {
            guard let focusedTimer = getFocusedTimer(), focusedTimer.isContentValid() else {
                return
            }
            
            sendingTest = true
            Task {
                await controller.sendTest(for: focusedTimer, settings: settings)
                try? await Task.sleep(nanoseconds: 500_000_000)
                sendingTest = false
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
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
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .disabled(sendingTest || settings.isRunning || getFocusedTimer()?.isContentValid() != true)
        .frame(width: 380)
    }
    
    // MARK: - Helper Methods
    
    private func getFocusedTimer() -> TimerItem? {
        if let focusedID = settings.focusedTimerID {
            return settings.timers.first { $0.id == focusedID }
        }
        return settings.timers.first
    }
    
    private func toggleTimer(_ timer: TimerItem) {
        // 删除旧的 toggle 逻辑，不再需要
    }
}

// MARK: - Visual Effect Transparent View

struct VisualEffectTransparentView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // 保持设置不变
    }
}

// MARK: - Timer List Item View

struct TimerListItemView: View {
    let timer: TimerItem
    let isFocused: Bool
    let isRunning: Bool
    let onToggle: () -> Void
    let onFocus: () -> Void
    
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // 图标和名称
            HStack(spacing: 6) {
                Text(timer.emoji)
                    .font(.body)
                VStack(alignment: .leading, spacing: 2) {
                    Text(timer.name)
                        .font(.callout)
                        .lineLimit(1)
                    // 显示关键信息
                    HStack(spacing: 4) {
                        Text(timer.formattedInterval())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(timer.title.isEmpty ? timer.body : timer.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // 休息和自定义颜色标记
            HStack(spacing: DesignTokens.Spacing.xs) {
                if timer.isRestEnabled {
                    Image(systemName: "pause.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                        .help("休息 \(timer.formattedRestInterval())")
                }
                
                if timer.customColor != nil {
                    Circle()
                        .fill(timer.customColor?.toColor() ?? .gray)
                        .frame(width: 8, height: 8)
                        .help("自定义颜色")
                }
            }
            
            // 启动/停止按钮
            if timer.isContentValid() {
                Button {
                    if timer.isRunning {
                        controller.stopTimer(timer.id, settings: settings)
                    } else {
                        controller.startTimer(timer.id, settings: settings)
                    }
                } label: {
                    Image(systemName: timer.isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title3)
                        .foregroundStyle(timer.isRunning ? .orange : .green)
                }
                .buttonStyle(.plain)
                .help(timer.isRunning ? "暂停计时器" : "启动计时器")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadiusSmall)
                .fill(isFocused ? Color.blue.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadiusSmall)
                .strokeBorder(isFocused ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onFocus()
        }
    }
}
