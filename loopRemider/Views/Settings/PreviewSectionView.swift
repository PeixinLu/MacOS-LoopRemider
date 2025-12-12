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

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            // 预览区域
            previewArea
            
            Divider()
                .padding(.vertical, 8)
            
            // 启动/暂停控制
            controlSection
            
            // 测试按钮
            testButton
            
            Spacer()
        }
    }
    
    // MARK: - Preview Area
    
    private var previewArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye.fill")
                    .foregroundStyle(.blue)
                Text("实时预览")
                    .font(.headline)
            }
            
            // 预览容器 - 模拟屏幕外观
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
                        // 预览通知 - 固定在屏幕中央
                        GeometryReader { geometry in
                            let screenWidth = geometry.size.width - 16 // 减去边框
                            let screenHeight = geometry.size.height - 16
                            let notifWidth = settings.overlayWidth
                            let notifHeight = settings.overlayHeight
                            
                            // 计算缩放比例，确保通知不超出屏幕内边框
                            let widthScale = notifWidth > screenWidth ? screenWidth / notifWidth : 1.0
                            let heightScale = notifHeight > screenHeight ? screenHeight / notifHeight : 1.0
                            let scale = min(widthScale, heightScale, 1.0)
                            
                            // NSPanel外边框容器
                            ZStack {
                                // 此处不会添加颜色边框，因为NSPanel本身对应渲染
                                // 仅展示实际通知内容
                                OverlayNotificationView(
                                    emoji: settings.notifEmoji,
                                    title: settings.notifTitle,
                                    message: settings.notifBody,
                                    backgroundColor: settings.getOverlayColor(),
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
                        .padding(8) // 确保通知在边框内
                    )
            }
            .frame(width: 400, height: 250) // 16:10 屏幕比例
            
            Text("实际显示效果可能因系统设置而略有不同")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Control Section
    
    private var controlSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: settings.isRunning ? "play.circle.fill" : "pause.circle.fill")
                            .font(.title3)
                            .foregroundStyle(settings.isRunning ? (isResting ? .purple : .green) : .orange)
                        Text(settings.isRunning ? (isResting ? "休息中" : "运行中") : "已暂停")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(settings.isRunning ? (isResting ? .purple : .green) : .orange)
                    }
                    Text(settings.isRunning ? countdownText : "点击启动开始提醒")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit() // 等宽数字，避免跳动
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { settings.isRunning },
                    set: { newValue in
                        // 验证内容
                        if newValue && !settings.isContentValid() {
                            return
                        }
                        
                        settings.isRunning = newValue
                        if newValue {
                            controller.start(settings: settings)
                            // 启动时先将进度条归零，然后立即更新
                            progressValue = 0.0
                            countdownText = ""
                            // 稍微延迟一下，确保 lastFireDate 已更新
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                updateCountdown()
                            }
                        } else {
                            controller.stop()
                            countdownText = ""
                            progressValue = 0.0
                        }
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(!settings.isContentValid())
            }
            .padding(12)
            .background(
                ZStack(alignment: .leading) {
                    // 背景色
                    RoundedRectangle(cornerRadius: 8)
                        .fill(settings.isRunning ? (isResting ? Color.purple.opacity(0.1) : Color.green.opacity(0.1)) : Color.orange.opacity(0.1))
                    
                    // 进度条（仅运行时显示）
                    if settings.isRunning {
                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            (isResting ? Color.purple : Color.green).opacity(0.25),
                                            (isResting ? Color.purple : Color.green).opacity(0.15)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progressValue)
                                .animation(.linear(duration: 0.3), value: progressValue) // 平滑过渡
                        }
                    }
                    
                    // 边框
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(settings.isRunning ? (isResting ? Color.purple.opacity(0.3) : Color.green.opacity(0.3)) : Color.orange.opacity(0.3), lineWidth: 1)
                }
            )
            
            // 验证提示
            if !settings.isContentValid() {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("标题、描述和Emoji至少需要有一项不为空")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(width: 420)
    }
    
    // MARK: - Test Button
    
    private var testButton: some View {
        Button {
            // 验证内容
            guard settings.isContentValid() else {
                return
            }
            
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
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .disabled(sendingTest || settings.isRunning || !settings.isContentValid()) // 运行时或内容无效时禁用测试按钮
        .frame(width: 420)
    }
    
    // MARK: - Helper Methods
    
    private func updateCountdown() {
        guard settings.isRunning else {
            countdownText = ""
            progressValue = 0.0
            return
        }

        if isResting {
            // 休息状态
            let now = Date()
            let lastFire = settings.lastFireDate ?? now
            let restEnd = lastFire.addingTimeInterval(settings.restSeconds)
            let remaining = restEnd.timeIntervalSince(now)

            if remaining <= 1.0 {
                countdownText = "休息结束，即将开始..."
                progressValue = 1.0
                return
            }

            let elapsed = settings.restSeconds - remaining
            progressValue = max(0, min(1.0, elapsed / settings.restSeconds))

            let seconds = Int(remaining)
            let minutes = seconds / 60
            let secs = seconds % 60

            countdownText = String(format: "休息中... %d:%02d", minutes, secs)
        } else {
            // 正常计时状态
            let now = Date()
            let lastFire = settings.lastFireDate ?? now
            let nextFire = lastFire.addingTimeInterval(settings.intervalSeconds)
            let remaining = nextFire.timeIntervalSince(now)

            if remaining <= 1.0 {
                countdownText = "下次通知：即将发送..."
                progressValue = 1.0
                return
            }

            let elapsed = settings.intervalSeconds - remaining
            progressValue = max(0, min(1.0, elapsed / settings.intervalSeconds))

            let seconds = Int(remaining)
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            let secs = seconds % 60

            if hours > 0 {
                countdownText = String(format: "下次通知：%d:%02d:%02d", hours, minutes, secs)
            } else if minutes > 0 {
                countdownText = String(format: "下次通知：%d:%02d", minutes, secs)
            } else {
                countdownText = String(format: "下次通知：%d秒", secs)
            }
        }
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
