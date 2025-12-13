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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // 页面标题 - 固定
            PageHeader(
                icon: "wand.and.stars",
                iconColor: .purple,
                title: "动画和定位",
                subtitle: "自定义通知动画和位置"
            )
            
            // 内容区域
            if settings.notificationMode == .overlay {
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.md) {
                        // 屏幕选择
                        screenSelectionSection
                        
                        Divider().padding(.vertical, DesignTokens.Spacing.xs)
                        
                        // 位置和动画
                        positionSection
                        animationTypeSection
                        
                        Divider().padding(.vertical, DesignTokens.Spacing.xs)
                        
                        // 停留时间
                        stayDurationSection
                        
                        Divider().padding(.vertical, DesignTokens.Spacing.xs)
                        
                        // 渐透明设置
                        fadeOutToggleSection
                        
                        if settings.overlayEnableFadeOut {
                            fadeOutDelaySection
                            fadeOutDurationSection
                        }
                    }
                    .padding(.bottom, DesignTokens.Spacing.xl)
                    .padding(.trailing, DesignTokens.Spacing.lg)
                }
                
                if settings.isRunning {
                    LockCard(message: "请先暂停才能修改动画设置")
                }
            } else {
                // 系统通知模式提示
                EmptyStateView(
                    icon: "bell.badge.fill",
                    title: "仅在屏幕遮罩模式下可用",
                    subtitle: "请在基本设置中将通知方式改为屏幕遮罩"
                )
            }
        }
    }
    
    // MARK: - Setting Sections
    
    private var screenSelectionSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            SettingRow(icon: "display.2", iconColor: .indigo, title: "显示屏幕") {
                Picker("", selection: $settings.screenSelection) {
                    ForEach(AppSettings.ScreenSelection.allCases, id: \.self) { selection in
                        Text(selection.rawValue).tag(selection)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(settings.isRunning)
                .frame(width: 220)
            }
            
            InfoHint(settings.screenSelection.description, color: .indigo)
        }
    }
    
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            SettingRow(icon: "timer", iconColor: .orange, title: "停留时间") {
                let maxStayDuration = max(1.0, settings.intervalSeconds - 1.0)
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Slider(value: $settings.overlayStayDuration, in: 1...min(60, maxStayDuration), step: 0.5)
                        .disabled(settings.isRunning)
                        .frame(width: DesignTokens.Layout.sliderWidth)
                        .onChange(of: settings.overlayStayDuration) { _, _ in
                            settings.validateTimingSettings()
                        }
                    Text(String(format: "%.1f秒", settings.overlayStayDuration))
                        .font(DesignTokens.Typography.value)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                        .frame(width: DesignTokens.Layout.valueDisplayWidth, alignment: .trailing)
                }
            }
            
            InfoHint("通知显示后停留的时间，最大为下次通知时间-过渡动画时间", color: .orange)
        }
    }
    
    private var fadeOutToggleSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            SettingRow(icon: "eye.slash.fill", iconColor: .purple, title: "我透明了") {
                Toggle("", isOn: $settings.overlayEnableFadeOut)
                    .toggleStyle(.switch)
                    .disabled(settings.isRunning)
                    .labelsHidden()
            }
            
            InfoHint("为减少对内容的干扰，通知弹出后会慢慢变透明，直至下一个通知到来", color: .purple)
        }
    }
    
    private var fadeOutDelaySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            SettingRow(icon: "clock.arrow.2.circlepath", iconColor: .cyan, title: "变淡延迟") {
                let maxFadeOutDelay = max(0.5, settings.overlayStayDuration - settings.overlayFadeOutDuration)
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Slider(value: $settings.overlayFadeOutDelay, in: 0...maxFadeOutDelay, step: 0.5)
                        .disabled(settings.isRunning)
                        .frame(width: DesignTokens.Layout.sliderWidth)
                        .onChange(of: settings.overlayFadeOutDelay) { _, _ in
                            settings.validateTimingSettings()
                        }
                    Text(String(format: "%.1f秒", settings.overlayFadeOutDelay))
                        .font(DesignTokens.Typography.value)
                        .fontWeight(.medium)
                        .foregroundStyle(.cyan)
                        .frame(width: DesignTokens.Layout.valueDisplayWidth, alignment: .trailing)
                }
            }
            
            InfoHint("停留后多久开始变淡，最大为停留时间-变淡持续时间", color: .cyan)
        }
    }
    
    private var fadeOutDurationSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            SettingRow(icon: "clock.badge.checkmark.fill", iconColor: .green, title: "变淡持续") {
                let maxFadeOutDuration = max(0.5, settings.overlayStayDuration - settings.overlayFadeOutDelay)
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Slider(value: $settings.overlayFadeOutDuration, in: 0.5...maxFadeOutDuration, step: 0.5)
                        .disabled(settings.isRunning)
                        .frame(width: DesignTokens.Layout.sliderWidth)
                        .onChange(of: settings.overlayFadeOutDuration) { _, _ in
                            settings.validateTimingSettings()
                        }
                    Text(String(format: "%.1f秒", settings.overlayFadeOutDuration))
                        .font(DesignTokens.Typography.value)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                        .frame(width: DesignTokens.Layout.valueDisplayWidth, alignment: .trailing)
                }
            }
            
            InfoHint("变淡动画持续时间，最大为停留时间-变淡延迟", color: .green)
        }
    }
}
