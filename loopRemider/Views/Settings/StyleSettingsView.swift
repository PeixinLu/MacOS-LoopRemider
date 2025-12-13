//
//  StyleSettingsView.swift
//  loopRemider
//
//  Created by 数源 on 2025/12/8.
//

import SwiftUI

struct StyleSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // 页面标题
            PageHeader(
                icon: "paintbrush.pointed.fill",
                iconColor: .pink,
                title: "通知样式",
                subtitle: "自定义屏幕遮罩通知外观"
            )
            
            // 样式设置仅在overlay模式下可用
            if settings.notificationMode == .overlay {
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.md) {
                        // 颜色设置
                        colorSection
                        opacitySection
                        
                        Divider().padding(.vertical, DesignTokens.Spacing.xs)
                        
                        // 尺寸设置
                        widthSection
                        heightSection
                        
                        Divider().padding(.vertical, DesignTokens.Spacing.xs)
                        
                        // 外观设置
                        cornerRadiusSection
                        edgePaddingSection
                        contentSpacingSection
                        
                        Divider().padding(.vertical, DesignTokens.Spacing.xs)
                        
                        // 字体设置
                        titleFontSizeSection
                        bodyFontSizeSection
                        iconSizeSection
                        
                        Divider().padding(.vertical, DesignTokens.Spacing.xs)
                        
                        // 模糊效果
                        blurSection
                    }
                    .padding(.bottom, DesignTokens.Spacing.xl)
                }
                
                if settings.isRunning {
                    LockCard(message: "请先暂停才能修改样式设置")
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
    
    private var colorSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            SettingRow(icon: "paintpalette.fill", iconColor: .purple, title: "颜色") {
                Picker("", selection: $settings.overlayColor) {
                    ForEach(AppSettings.OverlayColor.allCases, id: \.self) { color in
                        Text(color.rawValue).tag(color)
                    }
                }
                .pickerStyle(.menu)
                .disabled(settings.isRunning)
                .frame(width: 120)
            }
            
            if settings.overlayColor == .custom {
                HStack {
                    Spacer().frame(width: DesignTokens.Layout.labelWidth)
                    ColorPicker("自定义", selection: $settings.overlayCustomColor, supportsOpacity: false)
                        .disabled(settings.isRunning)
                }
            }
        }
    }
    
    private var opacitySection: some View {
        SettingRow(icon: "circle.lefthalf.filled", iconColor: .orange, title: "不透明度") {
            SliderControl(
                value: $settings.overlayOpacity,
                range: 0.3...1.0,
                step: 0.05,
                format: "%.0f",
                unit: "%",
                color: .orange,
                disabled: settings.isRunning,
                valueMultiplier: 100
            )
        }
    }
    
    private var widthSection: some View {
        SettingRow(icon: "arrow.left.and.right", iconColor: .blue, title: "宽度") {
            SliderControl(
                value: $settings.overlayWidth,
                range: 50...600,
                step: 10,
                format: "%.0f",
                color: .blue,
                disabled: settings.isRunning
            )
        }
    }
    
    private var heightSection: some View {
        SettingRow(icon: "arrow.up.and.down", iconColor: .green, title: "高度") {
            SliderControl(
                value: $settings.overlayHeight,
                range: 30...300,
                step: 10,
                format: "%.0f",
                color: .green,
                disabled: settings.isRunning
            )
        }
    }
    
    private var cornerRadiusSection: some View {
        SettingRow(icon: "app.fill", iconColor: .indigo, title: "圆角") {
            SliderControl(
                value: $settings.overlayCornerRadius,
                range: 0...30,
                step: 2,
                format: "%.0f",
                color: .indigo,
                disabled: settings.isRunning
            )
        }
    }
    
    private var edgePaddingSection: some View {
        SettingRow(icon: "arrow.up.to.line.square.fill", iconColor: .teal, title: "屏幕边缘距离") {
            SliderControl(
                value: $settings.overlayEdgePadding,
                range: 0...100,
                step: 5,
                format: "%.0f",
                color: .teal,
                disabled: settings.isRunning
            )
        }
    }
    
    private var contentSpacingSection: some View {
        SettingRow(icon: "arrow.left.and.right.square", iconColor: .cyan, title: "图标与内容间距") {
            SliderControl(
                value: $settings.overlayContentSpacing,
                range: 4...30,
                step: 2,
                format: "%.0f",
                color: .cyan,
                disabled: settings.isRunning
            )
        }
    }
    
    private var titleFontSizeSection: some View {
        SettingRow(icon: "textformat.size", iconColor: .red, title: "标题字号") {
            SliderControl(
                value: $settings.overlayTitleFontSize,
                range: 12...30,
                step: 1,
                format: "%.0f",
                color: .red,
                disabled: settings.isRunning
            )
        }
    }
    
    private var bodyFontSizeSection: some View {
        SettingRow(icon: "text.alignleft", iconColor: .pink, title: "描述字号") {
            SliderControl(
                value: $settings.overlayBodyFontSize,
                range: 10...24,
                step: 1,
                format: "%.0f",
                color: .pink,
                disabled: settings.isRunning
            )
        }
    }
    
    private var iconSizeSection: some View {
        SettingRow(icon: "face.smiling", iconColor: .yellow, title: "图标大小") {
            SliderControl(
                value: $settings.overlayIconSize,
                range: 20...80,
                step: 5,
                format: "%.0f",
                color: .yellow,
                disabled: settings.isRunning
            )
        }
    }
    
    private var blurSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            SettingRow(icon: "camera.filters", iconColor: .purple, title: "模糊效果") {
                Toggle("", isOn: $settings.overlayUseBlur)
                    .toggleStyle(.switch)
                    .disabled(settings.isRunning)
                    .labelsHidden()
            }
            
            if settings.overlayUseBlur {
                SettingRow(icon: "slider.horizontal.3", iconColor: .purple, title: "模糊强度") {
                    SliderControl(
                        value: $settings.overlayBlurIntensity,
                        range: 0.1...1.0,
                        step: 0.1,
                        format: "%.0f",
                        unit: "%",
                        color: .purple,
                        disabled: settings.isRunning,
                        valueMultiplier: 100
                    )
                }
            }
        }
    }
}

// MARK: - Setting Row Helper

struct SettingRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        HStack {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(width: DesignTokens.Layout.labelWidth, alignment: .leading)
            
            Spacer()
            
            content()
        }
        .padding(.vertical, DesignTokens.Layout.rowVerticalPadding)
    }
}
