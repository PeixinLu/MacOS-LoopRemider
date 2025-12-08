//
//  AnimationSettingsView.swift
//  loopRemider
//
//  Created by 数源 on 2025/12/8.
//

import SwiftUI

struct AnimationSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 28))
                        .foregroundStyle(.purple.gradient)
                    Text("动画和定位")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                Text("自定义通知动画和位置")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)
            
            if settings.notificationMode == .overlay {
                ScrollView {
                    VStack(spacing: 16) {
                        Group {
                            // 位置
                            positionSection
                            
                            Divider().padding(.vertical, 4)
                            
                            // 动画类型
                            animationTypeSection
                            
                            Divider().padding(.vertical, 4)
                            
                            // 停留时间
                            stayDurationSection
                            
                            Divider().padding(.vertical, 4)
                            
                            // 渐透明开关
                            fadeOutToggleSection
                            
                            // 变淡延迟（仅当启用渐透明时显示）
                            if settings.overlayEnableFadeOut {
                                fadeOutDelaySection
                                
                                // 变淡持续时间
                                fadeOutDurationSection
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
                .padding(.bottom, 20)
                
                if settings.isRunning {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.orange)
                        Text("请先暂停才能修改动画设置")
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
                // 系统通知模式提示
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            }
        }
    }
    
    // MARK: - Setting Sections
    
    private var positionSection: some View {
        SettingRow(icon: "location.fill", iconColor: .blue, title: "位置") {
            Picker("", selection: $settings.overlayPosition) {
                ForEach(AppSettings.OverlayPosition.allCases, id: \.self) { position in
                    Text(position.rawValue).tag(position)
                }
            }
            .pickerStyle(.menu)
            .disabled(settings.isRunning)
            .frame(width: 120)
        }
    }
    
    private var animationTypeSection: some View {
        SettingRow(icon: "sparkles", iconColor: .pink, title: "动画类型") {
            Picker("", selection: $settings.animationStyle) {
                ForEach(AppSettings.AnimationStyle.allCases, id: \.self) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .disabled(settings.isRunning)
            .frame(width: 200)
        }
    }
    
    private var stayDurationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingRow(icon: "timer", iconColor: .orange, title: "停留时间") {
                let maxStayDuration = max(1.0, settings.intervalSeconds - 1.0)
                HStack(spacing: 8) {
                    Slider(value: $settings.overlayStayDuration, in: 1...min(60, maxStayDuration), step: 0.5)
                        .disabled(settings.isRunning)
                        .frame(width: 120)
                        .onChange(of: settings.overlayStayDuration) { _, _ in
                            settings.validateTimingSettings()
                        }
                    Text(String(format: "%.1f秒", settings.overlayStayDuration))
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                        .frame(width: 50)
                }
            }
            
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.6))
                Text("通知显示后停留的时间，最大为下次通知时间-过渡动画时间")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.leading, 24)
            .padding(.top, -8)
        }
    }
    
    private var fadeOutToggleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingRow(icon: "eye.slash.fill", iconColor: .purple, title: "我透明了") {
                Toggle("", isOn: $settings.overlayEnableFadeOut)
                    .toggleStyle(.switch)
                    .disabled(settings.isRunning)
                    .labelsHidden()
            }
            
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.purple.opacity(0.6))
                Text("为减少对内容的干扰，通知弹出后会慢慢变透明，直至下一个通知到来")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.leading, 24)
            .padding(.top, -8)
        }
    }
    
    private var fadeOutDelaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingRow(icon: "clock.arrow.2.circlepath", iconColor: .cyan, title: "变淡延迟") {
                let maxFadeOutDelay = max(0.5, settings.overlayStayDuration - settings.overlayFadeOutDuration)
                HStack(spacing: 8) {
                    Slider(value: $settings.overlayFadeOutDelay, in: 0...maxFadeOutDelay, step: 0.5)
                        .disabled(settings.isRunning)
                        .frame(width: 120)
                        .onChange(of: settings.overlayFadeOutDelay) { _, _ in
                            settings.validateTimingSettings()
                        }
                    Text(String(format: "%.1f秒", settings.overlayFadeOutDelay))
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundStyle(.cyan)
                        .frame(width: 50)
                }
            }
            
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.cyan.opacity(0.6))
                Text("停留后多久开始变淡，最大为停留时间-变淡持续时间")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.leading, 24)
            .padding(.top, -8)
        }
    }
    
    private var fadeOutDurationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingRow(icon: "clock.badge.checkmark.fill", iconColor: .green, title: "变淡持续") {
                let maxFadeOutDuration = max(0.5, settings.overlayStayDuration - settings.overlayFadeOutDelay)
                HStack(spacing: 8) {
                    Slider(value: $settings.overlayFadeOutDuration, in: 0.5...maxFadeOutDuration, step: 0.5)
                        .disabled(settings.isRunning)
                        .frame(width: 120)
                        .onChange(of: settings.overlayFadeOutDuration) { _, _ in
                            settings.validateTimingSettings()
                        }
                    Text(String(format: "%.1f秒", settings.overlayFadeOutDuration))
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                        .frame(width: 50)
                }
            }
            
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green.opacity(0.6))
                Text("变淡动画持续时间，最大为停留时间-变淡延迟")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.leading, 24)
            .padding(.top, -8)
        }
    }
}
